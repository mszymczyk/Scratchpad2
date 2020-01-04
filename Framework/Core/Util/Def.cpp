#include "Util_pch.h"
#include "SysIncludes.h"
#include "Def.h"
#include "Logger.h"

#if defined(_MSC_VER) && defined(_DEBUG)
#define new _DEBUG_NEW
#endif

void assertPrintAndBreak( const char* text )
{
	logErrorAlways(text);
	__debugbreak();
}

void assertPrintAndBreak2(const char* text, const char* msg)
{
	logErrorAlways(text);
	logErrorAlways(msg);
	__debugbreak();
}

void assertPrintAndBreak3( const char* format, ... )
{
	va_list	args;

	va_start( args, format );
	const u32 bufferOnStackSize = 2 * 1024;
	char str_buffer_onStack[bufferOnStackSize];
	const char* str_buffer = str_buffer_onStack;
	std::string str_buffer_onHeap;
	int str_bufferLen = vsnprintf( str_buffer_onStack, bufferOnStackSize, format, args );
	if ( str_bufferLen >= bufferOnStackSize || str_bufferLen < 0 )
	{
		// when there's not enough space in buffer, vsnprintf returns "encoding error" (value < 0)
		// in this case, alloc mem dynamically and call it again
		const u32 bufferOnHeapSize = 32 * 1024;
		str_buffer_onHeap.resize( bufferOnHeapSize );
		str_buffer = str_buffer_onHeap.c_str();
		str_bufferLen = vsnprintf( &str_buffer_onHeap[0], bufferOnHeapSize, format, args );
		if ( str_bufferLen >= bufferOnHeapSize )
			str_buffer_onHeap[bufferOnHeapSize - 1] = 0;
	}
	va_end( args );

	logErrorAlways( str_buffer );
	__debugbreak();
}

int spad_snprintf( char* buffer, size_t bufferSize, const char* format, ... )
{
	va_list	args;
	va_start( args, format );
	int ires = vsnprintf( buffer, bufferSize, format, args );
	va_end( args );

#if defined(_MSC_VER)

	if ( ires == (int)bufferSize )
	{
		SPAD_ASSERT2( false, "spad_snprintf output has been truncated!" );
		buffer[bufferSize - 1] = 0;
		return -1;
	}
	else if ( ires < 0 )
	{
		SPAD_ASSERT2( false, "spad_snprintf output has been truncated!" );
		buffer[bufferSize - 1] = 0;
		return -1;
	}
	else
	{
		return ires;
	}

#else

	if ( ires >= (int)bufferSize )
	{
		SPAD_ASSERT( false, "spad_snprintf output has been truncated!" );
		// null terminated character is appended always acoording to spec
		//
		//buffer[bufferSize-1] = 0;
		return -1;
	}
	else if ( ires < 0 )
	{
		SPAD_ASSERT( false, "spad_snprintf encoding error!" );
		buffer[0] = 0;
		return -1;
	}
	else
	{
		return ires;
	}

#endif //
}

#if defined _DEBUG

void operator delete( void *address )
{
	_free_dbg( address, _NORMAL_BLOCK );
}

void operator delete[]( void *address )
{
	_free_dbg( address, _NORMAL_BLOCK );
}

#endif //
