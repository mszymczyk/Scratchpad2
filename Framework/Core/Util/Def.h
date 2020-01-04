#pragma once

#include <stdint.h>
#include <stdio.h>
#include <tchar.h>
#include <string>
#include <vector>
#include <map>
#include <set>
#include <sstream>
#include <memory>
#include <mutex>
#include <thread>
#include <iostream>
#include <algorithm>

#define SPAD_ASSERTIONS_ENABLED 1

//#ifdef __cplusplus
//extern "C"
//{
//#endif //

#ifdef SPAD_ASSERTIONS_ENABLED
	#define AT __FILE__ ":" TOSTRING(__LINE__)
	#define STRINGIFY(x) #x
	#define TOSTRING(x) STRINGIFY(x)

	void assertPrintAndBreak( const char* text );
	void assertPrintAndBreak2( const char* text, const char* msg );
	void assertPrintAndBreak3( const char* format, ... );

	#if defined(_MSC_VER)

		#define SPAD_ASSERT(expression)			(void)( (!!(expression)) || (assertPrintAndBreak( "ASSERTION FAILED " #expression " " AT "\n" ), 0) )
		#define SPAD_ASSERT2(expression, msg)	(void)( (!!(expression)) || (assertPrintAndBreak2( "ASSERTION FAILED " #expression " " AT "\n", (msg) ), 0) )
		#define SPAD_ASSERTMSG(...)				assertPrintAndBreak3( __VA_ARGS__ )

	#endif //

	#define SPAD_ASSERT_ALWAYS(expression, msg) ((void)0)

#else // ! SPAD_ASSERTIONS_ENABLED
	#define SPAD_ASSERT(expression) ((void)0)
	#define SPAD_ASSERT2(expression, msg) ((void)0)
#endif // SPAD_ASSERTIONS_ENABLED

#define SPAD_STATIC_ASSERT(expr, msg) static_assert( expr, "static assertion failed: " #expr ": " msg )
#define cassert( xxx ) SPAD_STATIC_ASSERT( xxx, "" )

#define SPAD_NOT_IMPLEMENTED assertPrintAndBreak( "NOT IMPLEMENTED!" AT )

#if defined(_MSC_VER)

	#define SPAD_ALIGNMENT(alignment) __declspec(align(alignment))

#else	//PPU, SPU, other?

	// Macro for declaring aligned structures
	#define SPAD_ALIGNMENT(alignment) __attribute__((aligned(alignment)))

#endif // _MSC_VER


#define SPAD_CACHELINE_SIZE 64



#if defined _DEBUG

/**
* operator new():
*  Here is the overloaded new operator, responsible for allocating and tracking the requested
*  memory.
*
*  Return Type: void* -> A pointer to the requested memory.
*  Arguments:
*  	size_t size	     : The size of memory requested in BYTES
*  	const char *szFileName : The file responsible for requesting the allocation.
*  	int nLine	       : The line number within the file requesting the allocation.
*/
__forceinline void* operator new( size_t size, const char *szFileName, int nLine ) {
	return _malloc_dbg( size, _NORMAL_BLOCK, szFileName, nLine );
}

__forceinline void* operator new[]( size_t size, const char *szFileName, int nLine ) {
	return _malloc_dbg( size, _NORMAL_BLOCK, szFileName, nLine );
}

/**
* operator delete():
*  This routine is responsible for de-allocating the requested memory.
*
*  Return Type: void
*  Arguments:
*  	void *address	: A pointer to the memory to be de-allocated.
*/
void operator delete( void *address );
void operator delete[]( void *address );

// ***** These two routines should never get called, unless an error occures during the 
// ***** allocation process.  These need to be defined to make Visual C++ 6.0 happy.
// ***** If there was an allocation problem these method would be called automatically by 
// ***** the operating system.  C/C++ Users Journal (Vol. 19 No. 4 -> April 2001 pg. 60)  
// ***** has an excellent explanation of what is going on here.
__forceinline void operator delete( void *address, const char * /*szFileName*/, int /*nLine*/ ) {
	_free_dbg( address, _NORMAL_BLOCK );
}
__forceinline void operator delete[]( void *address, const char * /*szFileName*/, int /*nLine*/ ) {
	_free_dbg( address, _NORMAL_BLOCK );
}

#endif // _DEBUG
 

inline void* spadMallocAligned( size_t size, size_t alignment )
{
	void* ptr = _aligned_malloc( size, alignment );
	SPAD_ASSERT( ptr );
	return ptr;
}

inline void spadFreeAligned( void* address )
{
	_aligned_free( address );
}

#define spadFreeAligned2(x) { spadFreeAligned(x); x = nullptr; }

#if defined(_MSC_VER) && defined(_DEBUG)
/**
*	Be aware to add:
*		#if defined(_MSC_VER) && defined(_DEBUG)
*		#define new _DEBUG_NEW
*		#endif
*	at the beginning of a file that uses 'new' operator. Only then overloaded versions for tracking allocation
*	will work!!!
*/
#define _DEBUG_NEW   new(__FILE__, __LINE__)
#else
#define _DEBUG_NEW
#endif //

// see http://jmabille.github.io/blog/2014/12/06/aligned-memory-allocator/
// for implementing allocator for stl containers

typedef uint8_t u8;
typedef uint16_t u16;
typedef uint32_t u32;
typedef uint32_t uint;
typedef uint64_t u64;
typedef int8_t i8;
typedef int16_t i16;
typedef int32_t i32;
typedef int64_t i64;
typedef wchar_t wchar;

/**
	It differs from MS implementation and from standard c/c++.
	Buffer is filled with characters up to it's capacity (max bufferSize-1 characters). Null character is always written at the end.
	If output string fits buffer, number of characters written is returned, excluding terminating null character.
	If output string was too long, then negative value is returned.
*/
int spad_snprintf( char* buffer, size_t bufferSize, const char* format, ... );

/**
* Returns value aligned on requested boundry
* @remarks   alignment must be power of '2'
* @sa        spadAlignPtr2
* @return    uint32_t aligned value
* @param     uint32_t value value to align
* @param     uint32_t alignment must be power of '2'
*/
inline uint32_t spadAlignU32_2( uint32_t value, uint32_t alignment )
{
	SPAD_ASSERT2((alignment & (alignment-1)) == 0, "alignment must be multiple of 2");
	alignment--;
	return ( (value + alignment) & ~alignment );
}

/**
 * Returns value aligned on requested boundry
 * @remarks   alignment don't have to be power of '2'
 * @sa        
 * @return    uint32_t
 * @param     uint32_t size
 * @param     uint32_t alignment any value, non power of '2' are also valid
 */
inline uint32_t spadAlignU32(uint32_t size, uint32_t alignment)
{
	return ( (uint32_t)((size - 1) / alignment) + 1) * alignment;
}

inline uint64_t spadAlignU64_2( uint64_t val, uint64_t alignment )
{
	SPAD_ASSERT2( ( alignment & ( alignment - 1 ) ) == 0, "alignment must be multiple of 2" );
	alignment--;
	return ( (val + alignment) & ~alignment );
}

inline size_t spadAlignPowerOfTwo( size_t val, size_t alignment )
{
	//SPAD_ASSERT2( ( alignment & ( alignment - 1 ) ) == 0, "alignment must be multiple of 2" );
	alignment--;
	return ( ( val + alignment ) & ~alignment );
}


#define ARRAY_COUNT(x) ((sizeof(x)/sizeof(0[x])) / ((size_t)(!(sizeof(x) % sizeof(0[x])))))



// Implementation detail for truncate_cast to get it to work correctly for enum types where we
// need to operate on the underlying type. That's because std::is_signed<EnumType> and std::is_unsigned<EnumType> is always false!
// Unfortunately we can't just use std::underlying_type for both enum and integral types because it only compiles for enum types,
// so we have to do trait-based dispatch.
template <typename T>
struct make_integral
{
	template <typename U, bool isEnum = false> struct dispatch { cassert( std::is_integral<T>::value ); using type = U; };
	template <typename U> struct dispatch<U, true> { using type = typename std::underlying_type<U>::type; };

	using type = typename dispatch<T, std::is_enum<T>::value>::type;
};

template <typename SmallType, typename BigType>
inline SmallType truncate_cast( BigType val )
{
	cassert( std::is_integral<BigType>::value || std::is_enum<BigType>::value );
	cassert( std::is_integral<SmallType>::value || std::is_enum<SmallType>::value );
	cassert( sizeof( BigType ) >= sizeof( SmallType ) );
	cassert( sizeof( BigType ) <= sizeof( uintmax_t ) );

	const SmallType ret = SmallType( val );

#if SPAD_ASSERTIONS_ENABLED
	using SmallIntType = typename make_integral<SmallType>::type;
	using BigIntType = typename make_integral<BigType>::type;

	constexpr bool isSmallTypeSigned = std::is_signed<SmallIntType>::value;
	constexpr bool isBigTypeSigned = std::is_signed<BigIntType>::value;

#ifdef _MSC_VER
#pragma warning( suppress: 6326 ) // 6326: Potential comparison of a constant with another constant.
#endif
	constexpr bool same_signedness = isBigTypeSigned == isSmallTypeSigned;
	using SignedBigType = std::make_signed_t<BigIntType>;
	using UnsignedBigType = std::make_unsigned_t<BigIntType>;
	using ComparisonType = std::conditional_t<same_signedness, BigIntType, std::conditional_t<isBigTypeSigned, UnsignedBigType, SignedBigType>>;

	constexpr auto maxSignedBigType = ( std::numeric_limits<SignedBigType>::max )( ); // Parentheses necessary here to prevent macro expansion for min/max macros
	constexpr auto minSmallType = ( std::numeric_limits<SmallIntType>::min )( );
	constexpr auto maxSmallType = ( std::numeric_limits<SmallIntType>::max )( );

	// To survive a signedness conversion in either direction, BigType needs to
	// be in the range 0 <= val <= signed_max;
	bool ok = same_signedness || val >= (BigType)0;
	ok = ok && ( same_signedness || val <= (BigType)maxSignedBigType );

	// Otherwise just check that we're correctly within limits.
	ok = ok && (ComparisonType)minSmallType <= (ComparisonType)val;
	ok = ok && (ComparisonType)maxSmallType >= (ComparisonType)val;

	if ( !ok )
	{
#ifdef _MSC_VER
		constexpr const char *const funcName = __FUNCSIG__;
#else
		constexpr const char *const funcName = __PRETTY_FUNCTION__;
#endif

		SPAD_ASSERTMSG( "%s (SmallType) %s 0x%jx == (BigType) %s 0x%jx", funcName,
			isSmallTypeSigned ? "signed" : "unsigned", static_cast<uintmax_t>( ret ),
			isBigTypeSigned ? "signed" : "unsigned", static_cast<uintmax_t>( val ) );
	}
#endif // #if SPAD_ASSERTIONS_ENABLED

	return ret;
}

// Like truncate_cast, but stores to the given output pointer.  This is useful for cases where you don't want to
// explicitly state the type (as doing so is fragile because the type of the cast has to match the type of the
// variable).
template <typename SmallType, typename BigType>
inline void truncate_store( SmallType *outValue, BigType inValue )
{
	*outValue = truncate_cast<SmallType>( inValue );
}
//#ifdef __cplusplus
//}
//#endif //

