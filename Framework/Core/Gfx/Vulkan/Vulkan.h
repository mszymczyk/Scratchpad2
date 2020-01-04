#pragma once

#define VK_USE_PLATFORM_WIN32_KHR
#define VK_NO_PROTOTYPES
//#include "vulkan\Vulkan-LoaderAndValidationLayers\include\vulkan\vulkan.h"
//#include "vulkan\Vulkan-LoaderAndValidationLayers\include\vulkan\vk_platform.h"
#include "vulkan\volk\volk.h"

namespace spad
{
	//inline void CheckVulkanResult( VkResult result, const char *msg )
	//{
	//	SPAD_ASSERT2( result == VK_SUCCESS, msg );
	//}

#define VulkanCall(x)                                                       \
    __pragma(warning(push))                                                 \
    __pragma(warning(disable:4127))                                         \
    do                                                                      \
    {                                                                       \
        VkResult res = x;                                                   \
        SPAD_ASSERT2( res == VK_SUCCESS, #x "failed");                      \
    }                                                                       \
    while(0)                                                                \
    __pragma(warning(pop))


	class Vulkan
	{
	public:
		~Vulkan();

		struct Param
		{
			HWND hWnd_ = nullptr;
			HINSTANCE hInstance_ = nullptr;
			u32 backBufferWidth_ = 1280;
			u32 backBufferHeight_ = 720;
			bool debugDevice = true;
		};

		bool StartUp( const Param& param );

		VolkDeviceTable table;

	private:
		void ShutDown();

	protected:
		//DXGI_FORMAT backBufferFormat_ = DXGI_FORMAT_R8G8B8A8_UNORM_SRGB;
		u32 backBufferWidth_ = 1280;
		u32 backBufferHeight_ = 720;
		bool debugDevice_ = false;

		//PFN_vkCreateInstance vkCreateInstance = NULL;
		std::vector<VkLayerProperties> layersAvailable_;
		std::vector<VkExtensionProperties> extensionsAvailable_;
		std::vector<VkPhysicalDevice> physicalDevicesAvailable_;

		VkInstance instance_ = nullptr;
		VkDebugReportCallbackEXT debugReportCallback_ = nullptr;
		VkSurfaceKHR surface_ = nullptr;
		VkPhysicalDevice physicalDevice_ = nullptr;
		VkPhysicalDeviceProperties physicalDeviceProperties_;
		uint32_t presentQueueIdx_ = 0xffffffff;
		VkDevice device_ = nullptr;
		VkSwapchainKHR swapChain_ = nullptr;

		VkQueue presentQueue_ = nullptr;
		VkCommandBuffer setupCmdBuffer_ = nullptr;
		VkCommandBuffer drawCmdBuffer_ = nullptr;

	};

	//extern ID3D11Device* gDx11Device;

} // namespace spad