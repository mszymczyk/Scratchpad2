#include "FxCompilerLibHlsl_pch.h"
#include "HlslCompile.h"
#include <Util/Threading.h>
#include <fstream>
#include <locale>
#include <codecvt>
#include <atlcore.h>
//#include "..\..\..\3rdParty\dxc\include\dxc\Support\FileIOHelper.h"
//#include "..\..\..\3rdParty\dxc\include\dxc\Support\microcom.h"

#if defined(_MSC_VER) && defined(_DEBUG)
#define new _DEBUG_NEW
#endif

namespace spad
{
namespace fxlib
{
namespace hlsl
{

static void CompileHlslProgramDXC( HlslProgramData& outData, const HlslCompileContext& hlslContext, const CompileContext& ctx, IncludeDependencies& fxFileIncludeDependencies, const FxFileHlslCompileOptions& hlslOptions, const FxFileCompileOptions& options, const FxFile& fxFile, const FxProgram& fxProg );


std::string CreateDebugFileName( const HlslCompileContext& hlslContext, const FxFile& fxFile, const FxProgram& fxProg, const char* fileExt )
{
	std::stringstream ss;
	ss << hlslContext.outputDiagnosticsDir;
	ss << GetFileNameWithoutExtension( fxFile.getFilename() );
	ss << '_';
	ss << fxProg.getEntryName();
	ss << '_';
	ss << fxProg.getIndex();
	ss << fileExt;

	return ss.str();
}

int CompileFxHlsl( const FxFile& fxFile, const CompileContext& ctx, const FxFileCompileOptions& options, const FxFileHlslCompileOptions& hlslOptions )
{
	std::string fileExt = spad::GetFileExtension( fxFile.getFilename() );
	if (fileExt != "hlsl")
		return 0;

	try
	{
		HlslCompileContext hlslContext;
		SetupHlslCompileContext( hlslContext, hlslOptions, fxFile );

		const char* outPaths[2] = { nullptr };
		u32 nOutPaths = 0;
		outPaths[nOutPaths++] = hlslContext.outputCompiledFileAbsolute.c_str();
		if (options.writeSource_)
			outPaths[nOutPaths++] = hlslContext.outputSourceFileAbsolute.c_str();

		if (!options.forceRecompile_
			&& !CheckIfRecompilationIsRequired( fxFile.getFileAbsolutePath().c_str(), hlslContext.outputDependFileAbsolute.c_str(), outPaths, nOutPaths, options.compilerTimestamp_, options.configuration_ ) )
		{
			// all files are up-to-date
			logInfo( "%s: hlsl output is up-to-date", fxFile.getFilename().c_str() );
			return 0;
		}

		logInfo( "%s: compiling hlsl", fxFile.getFilename().c_str() );

		CreateDirectoryRecursive( hlslOptions.outputDirectory_ );
		CreateDirectoryRecursive( hlslOptions.intermediateDirectory_ );
		CreateDirectoryRecursive( hlslOptions.outputDirectory_ );
		if (   hlslOptions.generatePreprocessedOutput
			|| hlslOptions.generateDisassembly
			)
			CreateDirectoryRecursive( hlslContext.outputDiagnosticsDir );

		IncludeDependencies includeDependencies;

		const FxProgramArray& uniquePrograms = fxFile.getUniquePrograms();
		const size_t nUniquePrograms = uniquePrograms.size();

		// compile all programs

		std::vector<HlslProgramData> compiledData;
		compiledData.resize( nUniquePrograms );

		u32 nHardwareThreads = GetNumHardwareThreads();
		// limiting number of threads gives better perf
		// there will be more threads in flight than hardware can support due to multiple files being compiled simultaneously
		// using builtin parallel_for seems to be little bit slower

		//ParallerFor( 0, uniquePrograms.size(), false, [&]( size_t index ) {
		//ParallelFor_threadPool( 0, uniquePrograms.size(), options.multithreaded_, [&]( size_t index ) {
		//ParallelFor( 0, uniquePrograms.size(), options.multithreaded_ ? -1 : 1, [&]( size_t index ) {
		ParallelFor( 0, uniquePrograms.size(), options.multithreaded_ ? (nHardwareThreads / 2) : 1, [&]( size_t index ) {
			const FxProgram& fxProg = *uniquePrograms[index].get();
			if ( hlslOptions.useDXC )
			{
				CompileHlslProgramDXC( compiledData[index], hlslContext, ctx, includeDependencies, hlslOptions, options, fxFile, fxProg );
			}
			else
			{
				CompileHlslProgram( compiledData[index], hlslContext, ctx, includeDependencies, hlslOptions, options, fxFile, fxProg );
			}
			return 0;
		} );

		// write compiled programs

		WriteCompiledFx( compiledData, hlslContext, hlslOptions, options, fxFile );

		CreateDirectoryRecursive( hlslOptions.intermediateDirectory_, hlslContext.outputDependFile );
		includeDependencies.writeToFile( hlslContext.outputDependFileAbsolute, options.configuration_ );

		return 0;
	}
	catch (HlslException ex)
	{
		logError( "HLSL Compiler error (DXC==%d)", (int)hlslOptions.useDXC );
		logError( ex.GetHlslErrorMessage().c_str() );
		return -1;
	}
	catch (Exception ex)
	{
		logError( "compileFxFile failed. Err=%s", ex.GetMessage().c_str() );
		return -1;
	}
}

void SetupHlslCompileContext( HlslCompileContext& ctx, const FxFileHlslCompileOptions& hlslOptions, const FxFile& fxFile )
{
	const std::string& dstDir = hlslOptions.outputDirectory_;
	ctx.outputSourceFile = "src\\" + fxFile.getFilename();
	ctx.outputSourceFileAbsolute = dstDir + ctx.outputSourceFile;

	std::string pathWithoutExt = GetFilePathWithoutExtension( fxFile.getFilename() );

	std::stringstream cf;
	cf << "compiled\\";
	cf << pathWithoutExt;
	cf << ".hlslc_packed";
	ctx.outputCompiledFile = cf.str();
	ctx.outputCompiledFileAbsolute = dstDir + ctx.outputCompiledFile;

	ctx.outputDependFile = GetFilePathWithoutExtension( fxFile.getFilename() ) + ".hlsl_depend";
	ctx.outputDependFileAbsolute = hlslOptions.intermediateDirectory_ + ctx.outputDependFile;

	ctx.outputDiagnosticsDir = dstDir + "compiledDiag\\" + GetFilePathWithoutExtension(fxFile.getFilename());
}

template<class ShaderInclude>
static std::string _FixHlslErrorMessage( const char* msg, const ShaderInclude& includes, IncludeCache* includeCache )
{
	// sometimes hlsl output contains path to a file that is relative and visual studio isn't smart enough to
	// redirect us to correct file/line when double clicking on error message
	// we try to replace this relative file with absolute file path so the visual studio knows where to jump
	std::istringstream ssIn( msg );
	std::string line;
	std::stringstream ss;

	const std::set<std::string>& visitedDirectories = includes.GetVisitedDirectories();

	while ( ssIn )
	{
		getline( ssIn, line );
		ss << line << "\n";

		if ( line.empty() )
		{
			continue;
		}

		std::string::size_type openBracePos = line.find( '(' );
		if ( openBracePos == std::string::npos )
		{
			continue;
		}

		std::string::size_type closeBracePos = line.find( "): ", openBracePos );
		if ( closeBracePos == std::string::npos )
		{
			continue;
		}

		if ( closeBracePos > openBracePos + 3 )
		{
			std::string filenameWithDir = line.substr( 0, openBracePos );
			for ( const auto& dir : visitedDirectories )
			{
				std::string filenameAbs = dir + filenameWithDir;
				const IncludeCache::File* f = includeCache->getFile( filenameAbs.c_str() );
				if ( f )
				{
					line.replace( 0, openBracePos, f->absolutePath_ );
					ss << line << " (guessed filename)\n";
					break;
				}
			}
		}
	}

	return ss.str();
}

void CompileHlslProgram( HlslProgramData& outData, const HlslCompileContext& hlslContext, const CompileContext& ctx, IncludeDependencies& fxFileIncludeDependencies, const FxFileHlslCompileOptions& hlslOptions, const FxFileCompileOptions& options, const FxFile& fxFile, const FxProgram& fxProg )
{
	if ( options.logProgress_ )
		logInfo( "Compiling %s:%s", fxFile.getFileAbsolutePath().c_str(), fxProg.getUniqueName().c_str() );

	const char* profiles[eProgramType_count] = {
		"vs_",
		"ps_",
		"gs_",
		"cs_"
	};

	char profileName[16];
	strcpy( profileName, profiles[fxProg.getProgramType()] );
	strcpy( profileName + 3, "5_0" );

	// defines
	//
	const std::vector<FxProgDefine>& progCDefines = fxProg.getCdefines();
	const size_t nProgCDefines = progCDefines.size();

	std::vector<D3D10_SHADER_MACRO> defines;
	defines.reserve( nProgCDefines + options.defines_.size() + 6 );

	for ( size_t icd = 0; icd < nProgCDefines; ++icd )
	{
		const FxProgDefine& src = progCDefines[icd];
		defines.push_back( { src.name_.c_str(), src.value_.c_str() } );
	}

	for ( size_t iud = 0; iud < options.defines_.size(); ++iud )
	{
		const FxProgDefine& src = options.defines_[iud];
		defines.push_back( { src.name_.c_str(), src.value_.c_str() } );
	}

	char entryDefine[256];
	spad_snprintf( entryDefine, 256, "prog_%s", fxProg.getEntryName().c_str() );
	{
		defines.push_back( { entryDefine, "1" } );
	}

	if ( fxProg.getProgramType() == eProgramType_vertexShader )
	{
		defines.push_back( { "progType_vp", "1" } );
		defines.push_back( { "__VERTEX__", "1" } );
	}
	else if ( fxProg.getProgramType() == eProgramType_pixelShader )
	{
		defines.push_back( { "progType_fp", "1" } );
		defines.push_back( { "__PIXEL__", "1" } );
	}
	else if ( fxProg.getProgramType() == eProgramType_geometryShader )
	{
		defines.push_back( { "progType_gp", "1" } );
		defines.push_back( { "__GEOMETRY__", "1" } );
	}
	else if ( fxProg.getProgramType() == eProgramType_computeShader )
	{
		defines.push_back( { "progType_cp", "1" } );
		defines.push_back( { "__COMPUTE__", "1" } );
	}

	if ( options.configuration_ == FxCompileConfiguration::shipping )
		defines.push_back( { "SHIPPING", "1" } );

	defines.push_back( { "__HLSL__", "1" } );

	// hlsl compiler requires that defines end with two nullptrs
	defines.push_back( { nullptr, nullptr } );

	// compiler flags
	UINT flagCombination = 0;

	flagCombination |= D3DCOMPILE_WARNINGS_ARE_ERRORS;

	if ( options.compileForDebugging_ )
	{
		flagCombination |= D3DCOMPILE_DEBUG;
		flagCombination |= D3DCOMPILE_SKIP_OPTIMIZATION;
		flagCombination |= D3DCOMPILE_AVOID_FLOW_CONTROL;
	}
	else
	{
		if ( !( flagCombination & ( D3DCOMPILE_OPTIMIZATION_LEVEL0 | D3DCOMPILE_OPTIMIZATION_LEVEL1 | D3DCOMPILE_OPTIMIZATION_LEVEL2 | D3DCOMPILE_OPTIMIZATION_LEVEL3 ) ) )
		{
			flagCombination |= D3DCOMPILE_OPTIMIZATION_LEVEL1;
		}
	}

	flagCombination |= hlslOptions.dxCompilerFlags;

	//std::string cflags;
	//std::vector<std::string> cflagsStorage;
	//std::vector<const char*> cflagsPointers;
	//if ( ExtractCompilerFlags( fxProg, "cflags_hlsl", cflags, cflagsStorage, cflagsPointers ) )
	//	if ( ParseOptions( &cflagsPointers[0], (int)cflagsPointers.size(), sceOptions ) )
	//		THROW_MESSAGE( "Error while parsing hlsl compiler flags! %s.%s", fxFile.getFilename().c_str(), fxProg.entryName.c_str() );

	HRESULT hr = S_OK;
	ID3D10BlobPtr shaderBlob = NULL;
	ID3D10BlobPtr errBlob = NULL;

	IncludeDependencies includeDependencies; // local include dependencies, merged later with global
	HlslShaderInclude hlslInclude( ctx, options, fxFile, includeDependencies );

	hr = D3DCompile(
		fxFile.getSourceCode().c_str(),
		fxFile.getSourceCode().length(),
		fxFile.getFilename().c_str(),
		&defines[0], // __in   const D3D10_SHADER_MACRO *pDefines,
		&hlslInclude,
		fxProg.getEntryName().c_str(), //__in   LPCSTR pFunctionName,
		profileName, //__in   LPCSTR pProfile,
		flagCombination, // __in   UINT Flags1,
		0, // __in   UINT Flags2,
		&shaderBlob, // __out  ID3D10Blob **ppShader,
		&errBlob // __out  ID3D10Blob **ppErrorMsgs,
	);

	if ( FAILED( hr ) )
	{
		std::string errMsg = Exception::FormatMessage( "Error '0x%x' while compiling program '%s:%s'!", (u32)hr, fxFile.getFileAbsolutePath().c_str(), fxProg.getUniqueName().c_str() );
		if ( errBlob )
		{
			const char* err = reinterpret_cast<const char*>( errBlob->GetBufferPointer() );
			std::string errFixed = _FixHlslErrorMessage( err, hlslInclude, ctx.includeCache );
			THROW_HLSL_EXCEPTION(
				std::move( errMsg ),
				errFixed.c_str(),
				hr
			);
		}
		else
		{
			THROW_HLSL_EXCEPTION( std::move( errMsg ), "", hr );
		}
	}

	outData.shaderBlob_ = shaderBlob;

	if ( fxProg.getProgramType() == eProgramType_vertexShader )
	{
		hr = D3DGetInputSignatureBlob( shaderBlob->GetBufferPointer(), shaderBlob->GetBufferSize(), &outData.vsSignatureBlob_ );
		if ( FAILED( hr ) )
		{
			std::string errMsg = Exception::FormatMessage( "D3DGetInputSignatureBlob failed. Err=0x%x while compiling program '%s:%s'!", (u32)hr, fxFile.getFileAbsolutePath().c_str(), fxProg.getUniqueName().c_str() );
			THROW_HLSL_EXCEPTION( std::move( errMsg ), "", hr );
		}
	}

	if ( hlslOptions.generatePreprocessedOutput )
	{
		ID3D10BlobPtr shaderPreprocessBlob = NULL;

		hr = D3DPreprocess(
			fxFile.getSourceCode().c_str(),
			fxFile.getSourceCode().length(),
			fxFile.getFilename().c_str(),
			&defines[0],
			&hlslInclude,
			&shaderPreprocessBlob,
			&errBlob
		);

		if ( FAILED( hr ) )
		{
			std::string errMsg = Exception::FormatMessage( "Error '0x%x' while preprocessing program '%s:%s'!", (u32)hr, fxFile.getFileAbsolutePath().c_str(), fxProg.getUniqueName().c_str() );
			if ( errBlob )
			{
				THROW_HLSL_EXCEPTION(
					std::move( errMsg ),
					reinterpret_cast<const char*>( errBlob->GetBufferPointer() ),
					hr
				);
			}
			else
			{
				THROW_HLSL_EXCEPTION( std::move( errMsg ), "", hr );
			}
		}

		const std::string filename = CreateDebugFileName( hlslContext, fxFile, fxProg, ".hlslc_prep" );
		CreateDirectoryRecursive( filename );

		std::ofstream of( filename.c_str() );
		if ( ! of )
			THROW_MESSAGE( "Couldn't open file '%s' for writing", filename.c_str() );

		//of << "// cflags passed to compiler:" << std::endl;
		//of << "// " << cflags << std::endl;
		//of << std::endl;

		const size_t nDefines = defines.size();

		of << "// defines passed to compiler:" << std::endl;
		for ( size_t idefine = 0; idefine < nDefines - 1; ++idefine )
		{
			const D3D10_SHADER_MACRO& d = defines[idefine];
			of << "// " << d.Name << '=' << d.Definition << std::endl;
		}
		of << std::endl;

		of.write( (const char*)shaderPreprocessBlob->GetBufferPointer(), shaderPreprocessBlob->GetBufferSize() );

		of.close();
	}

	if ( hlslOptions.generateDisassembly )
	{
		// generate disassembly and dump it to file

		ID3D10BlobPtr dissasemblyBlob = NULL;

		hr = D3DDisassemble(
			outData.shaderBlob_->GetBufferPointer(),
			outData.shaderBlob_->GetBufferSize(),
			D3D_DISASM_ENABLE_INSTRUCTION_NUMBERING | D3D_DISASM_ENABLE_DEFAULT_VALUE_PRINTS,
			NULL,
			&dissasemblyBlob );

		if ( FAILED( hr ) )
		{
			std::string errMsg = Exception::FormatMessage( "Error '0x%x' while disassembling program '%s:%s'!", (u32)hr, fxFile.getFileAbsolutePath().c_str(), fxProg.getUniqueName().c_str() );
			THROW_HLSL_EXCEPTION( std::move( errMsg ), "", hr );
		}

		const std::string filename = CreateDebugFileName( hlslContext, fxFile, fxProg, "_hlslc_disassembly" );
		CreateDirectoryRecursive( filename );

		CallResult( WriteFileSync( filename.c_str(), dissasemblyBlob->GetBufferPointer(), dissasemblyBlob->GetBufferSize() ) );
	}

	// thread safe merge this file dependencies with global list
	fxFileIncludeDependencies.merge( includeDependencies );
}


std::wstring StringToWString( const std::string &s )
{
	return std::wstring_convert<std::codecvt<wchar_t, char, std::mbstate_t>>{}.from_bytes( s.data() );
}


std::string WStringToString( const std::wstring &s )
{
	return std::wstring_convert<std::codecvt<wchar_t, char, std::mbstate_t>>{}.to_bytes( s.data() );
}


template<typename TObject>
HRESULT DoBasicQueryInterface_recurse( TObject* /*self*/, REFIID /*iid*/, void** /*ppvObject*/ ) {
	return E_NOINTERFACE;
}
template<typename TObject, typename TInterface, typename... Ts>
HRESULT DoBasicQueryInterface_recurse( TObject* self, REFIID iid, void** ppvObject ) {
	if ( ppvObject == nullptr ) return E_POINTER;
	if ( IsEqualIID( iid, __uuidof( TInterface ) ) ) {
		*(TInterface**)ppvObject = self;
		self->AddRef();
		return S_OK;
	}
	return DoBasicQueryInterface_recurse<TObject, Ts...>( self, iid, ppvObject );
}
template<typename... Ts, typename TObject>
HRESULT DoBasicQueryInterface( TObject* self, REFIID iid, void** ppvObject ) {
	if ( ppvObject == nullptr ) return E_POINTER;

	// Support INoMarshal to void GIT shenanigans.
	if ( IsEqualIID( iid, __uuidof( IUnknown ) ) ||
		IsEqualIID( iid, __uuidof( INoMarshal ) ) ) {
		*ppvObject = reinterpret_cast<IUnknown*>( self );
		reinterpret_cast<IUnknown*>( self )->AddRef();
		return S_OK;
	}

	return DoBasicQueryInterface_recurse<TObject, Ts...>( self, iid, ppvObject );
}


#define DXC_MICROCOM_REF_FIELD(m_dwRef)                                        \
  volatile std::atomic_ulong m_dwRef = {0};
#define DXC_MICROCOM_ADDREF_IMPL(m_dwRef)                                      \
  ULONG STDMETHODCALLTYPE AddRef() override {                                  \
    return (ULONG)++m_dwRef;                                                   \
  }
#define DXC_MICROCOM_ADDREF_RELEASE_IMPL(m_dwRef)                              \
  DXC_MICROCOM_ADDREF_IMPL(m_dwRef)                                            \
  ULONG STDMETHODCALLTYPE Release() override {                                 \
    ULONG result = (ULONG)--m_dwRef;                                           \
    if (result == 0)                                                           \
      delete this;                                                             \
    return result;                                                             \
  }


class InternalDxcBlobEncoding : public IDxcBlobEncoding {
private:
	DXC_MICROCOM_REF_FIELD( m_dwRef ) // an underlying m_pMalloc that owns this
	LPCVOID m_Buffer = nullptr;
	SIZE_T m_BufferSize;
	unsigned m_EncodingKnown : 1;
	UINT32 m_CodePage;
public:
	DXC_MICROCOM_ADDREF_IMPL( m_dwRef )

	ULONG STDMETHODCALLTYPE Release() override
	{
		// Because blobs are also used by tests and utilities, we avoid using TLS.
		ULONG result = ( ULONG )--m_dwRef;
		if ( result == 0 ) {
			delete this;
		}
		return result;
	}

	HRESULT STDMETHODCALLTYPE QueryInterface( REFIID riid, void **ppvObject )
	{
		return DoBasicQueryInterface<IDxcBlob, IDxcBlobEncoding>( this, riid, ppvObject );
	}

	InternalDxcBlobEncoding( LPCVOID buffer, SIZE_T bufferSize, bool encodingKnown, UINT32 codePage )
	{
		this->m_Buffer = buffer;
		this->m_BufferSize = bufferSize;
		this->m_EncodingKnown = encodingKnown;
		this->m_CodePage = codePage;
		this->AddRef();
	}

	~InternalDxcBlobEncoding()
	{
	}

	virtual LPVOID STDMETHODCALLTYPE GetBufferPointer( void ) override
	{
		return (LPVOID)m_Buffer;
	}
	virtual SIZE_T STDMETHODCALLTYPE GetBufferSize( void ) override
	{
		return m_BufferSize;
	}
	virtual HRESULT STDMETHODCALLTYPE GetEncoding( _Out_ BOOL *pKnown, _Out_ UINT32 *pCodePage ) override
	{
		*pKnown = m_EncodingKnown ? TRUE : FALSE;
		*pCodePage = m_CodePage;
		return S_OK;
	}
};


HRESULT DxcCreateBlobWithEncodingFromPinned( LPCVOID pText, UINT32 size, UINT32 codePage, IDxcBlobEncoding **pBlobEncoding ) throw( )
{
	InternalDxcBlobEncoding *internalEncoding = new InternalDxcBlobEncoding( pText, size, true, codePage );
	*pBlobEncoding = internalEncoding;
	return S_OK;
}


class DXCShaderInclude : public IDxcIncludeHandler
{
public:
	DXCShaderInclude( const CompileContext& ctx, const FxFileCompileOptions& options, const FxFile& fxFile/*, IncludeCache& includeCache*/, IncludeDependencies& includeDependencies, IDxcLibrary *pLibrary )
		: ctx_( ctx )
		, options_( options )
		, fx_( fxFile )
		, includeDependencies_( includeDependencies )
		, pLibrary_( pLibrary )
	{
	}

	DXC_MICROCOM_ADDREF_RELEASE_IMPL( dwRef );

	HRESULT STDMETHODCALLTYPE QueryInterface( REFIID riid, void **ppvObject ) {
		return DoBasicQueryInterface<::IDxcIncludeHandler>( this, riid, ppvObject );
	}

	HRESULT LoadSource(
		_In_ LPCWSTR pFilename,                                   // Candidate filename.
		_COM_Outptr_result_maybenull_ IDxcBlob **ppIncludeSource  // Resultant source object for included file, nullptr if not found.
	)
	{
		const IncludeCache::File* f = nullptr;
		const IncludeCache::File* fp = nullptr;

		// search in directory of input file
		std::string dir = GetDirectoryFromFilePath( fx_.getFileAbsolutePath() );
		std::string filename = WStringToString( pFilename );
		std::string absPath = dir + filename;
		f = ctx_.includeCache->getFile( absPath.c_str() );

		if ( !f )
			// look for file in all given search directories
			f = ctx_.includeCache->searchFile( filename.c_str() );

		if ( f )
		{
			visitedDirectories_.insert( GetDirectoryFromFilePath( f->absolutePath_ ) );
			includeDependencies_.addDependencyNoLock( f->absolutePath_ );

			IDxcBlobEncoding *pSource;
			HRESULT hr = DxcCreateBlobWithEncodingFromPinned( f->sourceCode_.c_str(), truncate_cast<UINT32>( f->sourceCode_.size() ), CP_UTF8, &pSource );
			if ( FAILED( hr ) )
			{
				THROW_HLSL_EXCEPTION( "CreateBlobWithEncodingFromPinned failed", "", hr );
				return hr;
			}

			*ppIncludeSource = pSource;
			return S_OK;
		}

		if ( fp )
		{
			// try provide meaningful file and line in the error output
			std::istringstream ss( fp->sourceCode_ );
			std::string line;
			bool foundLine = false;
			u32 lineNo = 0;
			while ( ss )
			{
				++lineNo;

				getline( ss, line );
				if ( line.empty() )
					continue;

				std::string::size_type filenamePos = line.rfind( filename );
				if ( filenamePos != std::string::npos )
				{
					foundLine = true;
					break;
				}
			}

			if ( foundLine )
			{
				logError( "%s(%u,1): error: Couldn't open include '%s'", fp->absolutePath_.c_str(), lineNo, filename.c_str() );
				return S_FALSE;
			}
		}

		logError( "%s(1,1): error: Couldn't open include '%s'", fx_.getFileAbsolutePath().c_str(), filename.c_str() );

		return S_FALSE;
	}

	const std::set<std::string>& GetVisitedDirectories() const { return visitedDirectories_; }

private:
	const CompileContext& ctx_;
	const FxFileCompileOptions& options_;
	const FxFile& fx_;
	IncludeDependencies& includeDependencies_; // independent from CompileContext for better perf
	IDxcLibrary *pLibrary_;
	std::set<std::string> visitedDirectories_;
	DXC_MICROCOM_REF_FIELD( dwRef );
};

_COM_SMARTPTR_TYPEDEF( DXCShaderInclude, __uuidof( IDxcCompiler ) );


void CompileHlslProgramDXC( HlslProgramData& outData, const HlslCompileContext& hlslContext, const CompileContext& ctx, IncludeDependencies& fxFileIncludeDependencies, const FxFileHlslCompileOptions& hlslOptions, const FxFileCompileOptions& options, const FxFile& fxFile, const FxProgram& fxProg )
{
	if ( options.logProgress_ )
		logInfo( "Compiling %s:%s", fxFile.getFileAbsolutePath().c_str(), fxProg.getUniqueName().c_str() );

	const char* profiles[eProgramType_count] = {
		"vs_",
		"ps_",
		"gs_",
		"cs_"
	};

	char profileName[16];
	strcpy( profileName, profiles[fxProg.getProgramType()] );
	strcpy( profileName + 3, "6_2" );

	// defines
	const std::vector<FxProgDefine>& progCDefines = fxProg.getCdefines();
	const size_t nProgCDefines = progCDefines.size();

	struct DxcDefineWStringTmp
	{
		std::wstring Name;
		std::wstring Value;
	};

	std::vector<DxcDefine> defines;
	defines.reserve( nProgCDefines + options.defines_.size() + 6 );

	std::vector<DxcDefineWStringTmp> definesWString;
	definesWString.reserve( defines.capacity() );

	for ( size_t icd = 0; icd < nProgCDefines; ++icd )
	{
		const FxProgDefine& src = progCDefines[icd];
		definesWString.push_back( { StringToWString( src.name_ ), StringToWString( src.value_ ) } );
		defines.push_back( { definesWString.back().Name.c_str(), definesWString.back().Value.c_str() } );
	}

	for ( size_t iud = 0; iud < options.defines_.size(); ++iud )
	{
		const FxProgDefine& src = options.defines_[iud];
		definesWString.push_back( { StringToWString( src.name_ ), StringToWString( src.value_ ) } );
		defines.push_back( { definesWString.back().Name.c_str(), definesWString.back().Value.c_str() } );
	}

	char entryDefine[256];
	std::wstring entryDefineW;
	spad_snprintf( entryDefine, 256, "prog_%s", fxProg.getEntryName().c_str() );
	entryDefineW = StringToWString( entryDefine );
	{
		defines.push_back( { entryDefineW.c_str(), L"1" } );
	}

	if ( fxProg.getProgramType() == eProgramType_vertexShader )
	{
		defines.push_back( { L"progType_vp", L"1" } );
		defines.push_back( { L"__VERTEX__", L"1" } );
	}
	else if ( fxProg.getProgramType() == eProgramType_pixelShader )
	{
		defines.push_back( { L"progType_fp", L"1" } );
		defines.push_back( { L"__PIXEL__", L"1" } );
	}
	else if ( fxProg.getProgramType() == eProgramType_geometryShader )
	{
		defines.push_back( { L"progType_gp", L"1" } );
		defines.push_back( { L"__GEOMETRY__", L"1" } );
	}
	else if ( fxProg.getProgramType() == eProgramType_computeShader )
	{
		defines.push_back( { L"progType_cp", L"1" } );
		defines.push_back( { L"__COMPUTE__", L"1" } );
	}

	if ( options.configuration_ == FxCompileConfiguration::shipping )
		defines.push_back( { L"SHIPPING", L"1" } );

	defines.push_back( { L"__HLSL__", L"1" } );

	std::vector<LPCWSTR> compilerArgs;
	// compiler flags

	compilerArgs.push_back( L"WX" ); // Treat warnings as errors

	if ( options.compileForDebugging_ )
	{
		compilerArgs.push_back( L"Od" ); // Disable optimizations
		compilerArgs.push_back( L"Zi" ); // Enable debug information
		compilerArgs.push_back( L"Gfa" ); // Avoid float control constructs
	}
	else
	{
		//if ( !( flagCombination & ( D3DCOMPILE_OPTIMIZATION_LEVEL0 | D3DCOMPILE_OPTIMIZATION_LEVEL1 | D3DCOMPILE_OPTIMIZATION_LEVEL2 | D3DCOMPILE_OPTIMIZATION_LEVEL3 ) ) )
		//{
		//	flagCombination |= D3DCOMPILE_OPTIMIZATION_LEVEL1;
		//}
	}

	//flagCombination |= hlslOptions.dxCompilerFlags;

	if ( hlslOptions.emitSPIRV )
	{
		compilerArgs.push_back( L"-fspv-target-env=vulkan1.1" ); // Specify the target environment
		compilerArgs.push_back( L"-fspv-reflect" ); // Emit additional SPIR-V instructions to aid reflection
	}

	HRESULT hr = S_OK;

	IDxcLibraryPtr pLibrary;
	hr = DxcCreateInstance( CLSID_DxcLibrary, __uuidof( IDxcLibrary ), (void **)&pLibrary );
	if ( FAILED( hr ) )
	{
		THROW_HLSL_EXCEPTION( "DxcCreateInstance CLSID_DxcLibrary failed", "", hr );
	}

	IDxcBlobEncodingPtr pSource;
	//hr = pLibrary->CreateBlobWithEncodingFromPinned( fxFile.getSourceCode().c_str(), truncate_cast<UINT32>( fxFile.getSourceCode().size() ), CP_UTF8, &pSource );
	//hr = ::hlsl::DxcCreateBlobWithEncodingFromPinned( fxFile.getSourceCode().c_str(), truncate_cast<UINT32>( fxFile.getSourceCode().size() ), CP_UTF8, &pSource );
	hr = DxcCreateBlobWithEncodingFromPinned( fxFile.getSourceCode().c_str(), truncate_cast<UINT32>( fxFile.getSourceCode().size() ), CP_UTF8, &pSource );
	if ( FAILED( hr ) )
	{
		THROW_HLSL_EXCEPTION( "CreateBlobWithEncodingFromPinned failed", "", hr );
	}

	IDxcCompilerPtr pCompiler;
	hr = DxcCreateInstance( CLSID_DxcCompiler, __uuidof( IDxcCompiler ), (void **)&pCompiler );
	if ( FAILED( hr ) )
	{
		THROW_HLSL_EXCEPTION( "DxcCreateInstance CLSID_DxcCompiler failed", "", hr );
	}

	std::wstring sourceNameW = StringToWString( fxFile.getFilename() );
	std::wstring entryNameW = StringToWString( fxProg.getEntryName() );
	std::wstring profileNameW = StringToWString( profileName );

	IncludeDependencies includeDependencies; // local include dependencies, merged later with global
	DXCShaderIncludePtr hlslInclude = new DXCShaderInclude( ctx, options, fxFile, includeDependencies, nullptr );// pLibrary );

	IDxcOperationResultPtr pResult;
	hr = pCompiler->Compile(
		pSource,										// program text
		sourceNameW.c_str(),							// source name, mostly for error messages
		entryNameW.c_str(),								// entry point function
		profileNameW.c_str(),							// target profile
		compilerArgs.data(),							// compilation arguments
		truncate_cast<UINT32>( compilerArgs.size() ),	// number of compilation arguments
		defines.data(),									// name/value defines and their count
		truncate_cast<UINT32>( defines.size() ),		//
		hlslInclude,									// handler for #include directives
		&pResult );

	if ( FAILED( hr ) )
	{
		THROW_HLSL_EXCEPTION( "IDxcCompiler::Compile failed", "", hr );
	}

	HRESULT hrCompilation;
	pResult->GetStatus( &hrCompilation );

	if ( FAILED( hrCompilation ) )
	{
		IDxcBlobEncodingPtr pPrintBlob, pPrintBlob8;
		pResult->GetErrorBuffer( &pPrintBlob );

		std::string errMsg = Exception::FormatMessage( "DXC Error '0x%x' while compiling program with '%s:%s'!", (u32)hrCompilation, fxFile.getFileAbsolutePath().c_str(), fxProg.getUniqueName().c_str() );
		if ( pPrintBlob )
		{
			// We can use the library to get our preferred encoding.
			pLibrary->GetBlobAsUtf8( pPrintBlob, &pPrintBlob8 );

			const char* err = reinterpret_cast<const char*>( pPrintBlob8->GetBufferPointer() );
			std::string errFixed = _FixHlslErrorMessage( err, *hlslInclude, ctx.includeCache );

			THROW_HLSL_EXCEPTION(
				std::move( errMsg ),
				errFixed.c_str(),
				hr
			);
		}
		else
		{
			THROW_HLSL_EXCEPTION( std::move( errMsg ), "", hr );
		}
	}

	pResult->GetResult( &outData.shaderBlobDxc_ );

	if ( hlslOptions.generatePreprocessedOutput )
	{
		IDxcOperationResultPtr pResultPreprocess;
		hr = pCompiler->Preprocess(
			pSource,										// program text
			sourceNameW.c_str(),							// source name, mostly for error messages
			compilerArgs.data(),							// compilation arguments
			truncate_cast<UINT32>( compilerArgs.size() ),	// number of compilation arguments
			defines.data(),									// name/value defines and their count
			truncate_cast<UINT32>( defines.size() ),		//
			hlslInclude,									// handler for #include directives
			&pResultPreprocess );

		if ( FAILED( hr ) )
		{
			THROW_HLSL_EXCEPTION( "IDxcCompiler::Preprocess failed", "", hr );
		}

		HRESULT hrPreprocess;
		pResultPreprocess->GetStatus( &hrPreprocess );

		if ( FAILED( hrPreprocess ) )
		{
			IDxcBlobEncodingPtr pPrintBlob, pPrintBlob8;
			pResultPreprocess->GetErrorBuffer( &pPrintBlob );

			std::string errMsg = Exception::FormatMessage( "DXC Error '0x%x' while preprocessing program '%s:%s'!", (u32)hrPreprocess, fxFile.getFileAbsolutePath().c_str(), fxProg.getUniqueName().c_str() );
			if ( pPrintBlob )
			{
				// We can use the library to get our preferred encoding.
				pLibrary->GetBlobAsUtf8( pPrintBlob, &pPrintBlob8 );

				const char* err = reinterpret_cast<const char*>( pPrintBlob8->GetBufferPointer() );
				std::string errFixed = _FixHlslErrorMessage( err, *hlslInclude, ctx.includeCache );

				THROW_HLSL_EXCEPTION(
					std::move( errMsg ),
					errFixed.c_str(),
					hr
				);
			}
			else
			{
				THROW_HLSL_EXCEPTION( std::move( errMsg ), "", hr );
			}
		}

		const std::string filename = CreateDebugFileName( hlslContext, fxFile, fxProg, ".hlslc_prep" );
		CreateDirectoryRecursive( filename );

		std::ofstream of( filename.c_str() );
		if ( !of )
			THROW_MESSAGE( "Couldn't open file '%s' for writing", filename.c_str() );

		//of << "// cflags passed to compiler:" << std::endl;
		//of << "// " << cflags << std::endl;
		//of << std::endl;

		const size_t nDefines = defines.size();

		of << "// defines passed to compiler:" << std::endl;
		for ( size_t idefine = 0; idefine < nDefines - 1; ++idefine )
		{
			const DxcDefine &d = defines[idefine];
			of << "// " << WStringToString( d.Name ) << '=' << WStringToString( d.Value ) << std::endl;
		}
		of << std::endl;

		IDxcBlobPtr shaderPreprocessBlob;
		pResultPreprocess->GetResult( &shaderPreprocessBlob );

		of.write( (const char*)shaderPreprocessBlob->GetBufferPointer(), shaderPreprocessBlob->GetBufferSize() );

		of.close();
	}

	if ( hlslOptions.generateDisassembly )
	{
		// generate disassembly and dump it to file

		IDxcBlobEncodingPtr dissasemblyBlob;

		hr = pCompiler->Disassemble( outData.shaderBlobDxc_, &dissasemblyBlob );

		if ( FAILED( hr ) )
		{
			std::string errMsg = Exception::FormatMessage( "DXC Error '0x%x' while disassembling program '%s:%s'!", (u32)hr, fxFile.getFileAbsolutePath().c_str(), fxProg.getUniqueName().c_str() );
			THROW_HLSL_EXCEPTION( std::move( errMsg ), "", hr );
		}

		const std::string filename = CreateDebugFileName( hlslContext, fxFile, fxProg, "_hlslc_disassembly" );
		CreateDirectoryRecursive( filename );

		CallResult( WriteFileSync( filename.c_str(), dissasemblyBlob->GetBufferPointer(), dissasemblyBlob->GetBufferSize() ) );
	}

	// thread safe merge this file dependencies with global list
	fxFileIncludeDependencies.merge( includeDependencies );
}


void WriteCompiledFx( const std::vector<HlslProgramData>& outData, const HlslCompileContext& hlslContext, const FxFileHlslCompileOptions& hlslOptions, const FxFileCompileOptions& options, const FxFile& fxFile )
{
	if ( options.writeSource_ )
	{
		if ( PathsPointToTheSameFile( hlslContext.outputSourceFileAbsolute, fxFile.getFileAbsolutePath() ) )
		{
			logInfo( "Skipping write '%s' (it's the source file?)", hlslContext.outputSourceFileAbsolute.c_str() );
		}
		else
		{
			if ( options.logProgress_ )
				logInfo( "Writing '%s'", hlslContext.outputSourceFileAbsolute.c_str() );

			CreateDirectoryRecursive( hlslOptions.outputDirectory_, hlslContext.outputSourceFile );
			const char* source;
			size_t sourceLen;
			fxFile.getOrigSourceCode( source, sourceLen );
			CallResult( WriteFileSync( hlslContext.outputSourceFileAbsolute.c_str(), reinterpret_cast<const void*>( source ), sourceLen ) );
		}
	}

	if ( options.writeCompiledPacked_ )
	{
		//if ( options.logProgress_ )
			logInfo( "Writing '%s'", hlslContext.outputCompiledFileAbsolute.c_str() );

		CreateDirectoryRecursive( hlslOptions.outputDirectory_, hlslContext.outputCompiledFile );

		FILE* ofs = fopen( hlslContext.outputCompiledFileAbsolute.c_str(), "wb" );
		if ( !ofs )
			THROW_MESSAGE( "Couldn't open file '%s' for writing", hlslContext.outputCompiledFileAbsolute.c_str() );

		// write header
		WriteCompiledFxFileHeader( ofs, fxFile, options.configuration_ );

		// write all unique programs
		const FxProgramArray& uniquePrograms = fxFile.getUniquePrograms();
		const size_t nUniquePrograms = uniquePrograms.size();
		SPAD_ASSERT( nUniquePrograms == outData.size() );

		AppendU32( ofs, (u32)nUniquePrograms );

		for ( size_t iprog = 0; iprog < nUniquePrograms; ++iprog )
		{
			const FxProgram& prog = *uniquePrograms[iprog];
			const HlslProgramData& data = outData[iprog];

			AppendU32( ofs, (u32)prog.getProgramType() );
			AppendString( ofs, prog.getUniqueName() );

			if ( data.shaderBlob_ )
			{
				AppendU32( ofs, truncate_cast<u32>( data.shaderBlob_->GetBufferSize() ) );
				fwrite( data.shaderBlob_->GetBufferPointer(), truncate_cast<u32>( data.shaderBlob_->GetBufferSize() ), 1, ofs );
			}
			else
			{
				AppendU32( ofs, truncate_cast<u32>( data.shaderBlobDxc_->GetBufferSize() ) );
				fwrite( data.shaderBlobDxc_->GetBufferPointer(), data.shaderBlobDxc_->GetBufferSize(), 1, ofs );
			}

			if ( data.shaderBlob_ && prog.getProgramType() == eProgramType_vertexShader )
			{
				AppendU32( ofs, (u32)data.vsSignatureBlob_->GetBufferSize() );
				fwrite( data.vsSignatureBlob_->GetBufferPointer(), truncate_cast<u32>( data.vsSignatureBlob_->GetBufferSize() ), 1, ofs );
			}
		}

		// write passes and combinations
		WriteCompiledFxFilePasses( ofs, fxFile );

		fclose( ofs );
	}
}

HRESULT HlslShaderInclude::Open( D3D_INCLUDE_TYPE /*IncludeType*/, LPCSTR pFileName, LPCVOID pParentData, LPCVOID *ppData, UINT *pBytes )
{
	const IncludeCache::File* f = nullptr;
	const IncludeCache::File* fp = nullptr;

	// treat all includes the same

	//if ( IncludeType == D3D_INCLUDE_LOCAL )
	//{
	//	std::string absPath = currentDir_.back().name_ + pFileName;
	//	f = ctx_.includeCache->getFile( absPath.c_str() );
	//}
	//else
	//{
	//	SPAD_ASSERT( IncludeType == D3D_INCLUDE_SYSTEM );
	//	f = ctx_.includeCache->searchFile( pFileName );
	//}

	if ( !pParentData )
	{
		// search in directory of input file
		std::string dir = GetDirectoryFromFilePath( fx_.getFileAbsolutePath() );
		std::string absPath = dir + pFileName;
		f = ctx_.includeCache->getFile( absPath.c_str() );
	}
	else
	{
		// search in directory of parent file
		fp = ctx_.includeCache->getFileByDataPtr( pParentData );
		std::string dir = GetDirectoryFromFilePath( fp->absolutePath_ );
		std::string absPath = dir + pFileName;
		f = ctx_.includeCache->getFile( absPath.c_str() );
	}

	if ( !f )
		// look for file in all given search directories
		f = ctx_.includeCache->searchFile( pFileName );

	if ( f )
	{
		//_SetCurrentDir( GetDirectoryFromFilePath( f->absolutePath_ ) );
		visitedDirectories_.insert( GetDirectoryFromFilePath( f->absolutePath_ ) );
		includeDependencies_.addDependencyNoLock( f->absolutePath_ );

		*ppData = f->sourceCode_.c_str();
		*pBytes = (UINT)f->sourceCode_.length();
		return S_OK;
	}

	if ( fp )
	{
		// try provide meaningful file and line in the error output
		std::string filename = pFileName;

		std::istringstream ss( fp->sourceCode_ );
		std::string line;
		bool foundLine = false;
		u32 lineNo = 0;
		while ( ss )
		{
			++lineNo;

			getline( ss, line );
			if ( line.empty() )
				continue;

			std::string::size_type filenamePos = line.rfind( filename );
			if ( filenamePos != std::string::npos )
			{
				foundLine = true;
				break;
			}
		}

		if ( foundLine )
		{
			logError( "%s(%u,1): error: Couldn't open include '%s'", fp->absolutePath_.c_str(), lineNo, pFileName );
			return S_FALSE;
		}
	}
	
	logError( "%s(1,1): error: Couldn't open include '%s'", fx_.getFileAbsolutePath().c_str(), pFileName );

	return S_FALSE;
}

HRESULT __stdcall HlslShaderInclude::Close( LPCVOID /*pData*/ )
{
	// pData is the pointer we returned in Open callback
	//const IncludeCache::File* f = ctx_.includeCache->getFileByDataPtr( pData );
	//if ( f )
	//{
	//	std::string dir = GetDirectoryFromFilePath( f->absolutePath_ );
	//	SPAD_ASSERT( currentDir_.back().name_ == dir && currentDir_.back().refCount_ > 0 );
	//	currentDir_.back().refCount_ -= 1;
	//	if ( currentDir_.back().refCount_ == 0 )
	//		currentDir_.pop_back();
	//}

	return S_OK;
}

//void HlslShaderInclude::_SetCurrentDir( std::string dir )
//{
//	if ( !currentDir_.empty() )
//	{
//		if ( currentDir_.back().name_ == dir )
//		{
//			currentDir_.back().refCount_ += 1;
//			return;
//		}
//	}
//
//	currentDir_.emplace_back( dir, 1 );
//}


} // namespace hlsl
} // namespace fxlib
} // namespace spad
