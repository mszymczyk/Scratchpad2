#include "VulkanTest_pch.h"
#include "VulkanTest.h"
#include <Gfx\DebugDraw.h>

namespace spad
{
	bool VulkanTest::StartUp()
	{
		return true;
	}

	void VulkanTest::ShutDown()
	{
	}

	void VulkanTest::UpdateAndRender( const Timer& /*timer*/ )
	{
	}


	void VulkanTest::KeyPressed( uint key, bool shift, bool alt, bool ctrl )
	{
		(void)shift;
		(void)alt;
		(void)ctrl;

		//if ( key == 'R' || key == 'r' )
		//{
		//	shader_ = LoadCompiledFxFile( "DataWin\\Shaders\\hlsl\\compiled\\LaneSwizzle.hlslc_packed" );
		//}
	}
}
