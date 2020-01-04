#include "VulkanTest_pch.h"
#include "VulkanTest.h"

using namespace spad;

int main(int /*argc*/, _TCHAR* /*argv*/[])
{
#ifdef _DEBUG
	int flag = _CrtSetDbgFlag( _CRTDBG_REPORT_FLAG );
	flag |= _CRTDBG_LEAK_CHECK_DF;
	//flag &= ~_CRTDBG_LEAK_CHECK_DF;
	flag |= _CRTDBG_ALLOC_MEM_DF;
	//flag |= _CRTDBG_CHECK_ALWAYS_DF;
	flag &= ~_CRTDBG_CHECK_ALWAYS_DF;
	_CrtSetDbgFlag( flag );
#endif

	CoInitialize( NULL );

	VulkanTest app;

	VulkanTest::Param param;
	param.appName = "VulkanTest";
	param.debugDxDevice_ = true;
	param.windowWidth = 512;
	param.windowHeight = 512;
	param.apiType_ = AppBase::APIType::Vulkan;

	if ( app.StartUpBase( param ) )
	{
		if ( app.StartUp() )
		{
			app.Loop();
		}
	}
	
	CoUninitialize();

	return 0;
}

