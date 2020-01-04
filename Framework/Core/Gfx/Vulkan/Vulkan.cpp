#include "Gfx_pch.h"
#include "Vulkan.h"

namespace spad
{

Vulkan::~Vulkan()
{
	ShutDown();
}

VKAPI_ATTR VkBool32 VKAPI_CALL MyDebugReportCallback( VkDebugReportFlagsEXT flags,
	VkDebugReportObjectTypeEXT objectType, uint64_t object, size_t location,
	int32_t messageCode, const char* pLayerPrefix, const char* pMessage, void* pUserData ) {

	return VK_FALSE;
}

bool Vulkan::StartUp( const Param& param )
{
	//backBufferFormat_ = param.backBufferFormat_;
	backBufferWidth_ = param.backBufferWidth_;
	backBufferHeight_ = param.backBufferHeight_;
	debugDevice_ = param.debugDevice;

	//HMODULE vulkan_module = LoadLibrary( "vulkan-1.dll" );
	//SPAD_ASSERT2( vulkan_module, "Failed to load vulkan module." );

	//vkCreateInstance = (PFN_vkCreateInstance)GetProcAddress( vulkan_module, "vkCreateInstance" );
	//SPAD_ASSERT2( vkCreateInstance, "Failed to load vkCreateInstance function pointer." );

	VulkanCall( volkInitialize() );

	uint32_t layerCount = 0;
	VulkanCall( vkEnumerateInstanceLayerProperties( &layerCount, NULL ) );

	SPAD_ASSERT2( layerCount != 0, "Failed to find any layer in your system." );

	layersAvailable_.resize( layerCount );
	vkEnumerateInstanceLayerProperties( &layerCount, layersAvailable_.data() );

	VkApplicationInfo applicationInfo;
	applicationInfo.sType = VK_STRUCTURE_TYPE_APPLICATION_INFO; // sType is a member of all structs
	applicationInfo.pNext = nullptr;                            // as is pNext and flag
	applicationInfo.pApplicationName = "My Vulkan";				// The name of our application
	applicationInfo.pEngineName = nullptr;                      // The name of the engine
	applicationInfo.engineVersion = 1;                          // The version of the engine
	applicationInfo.apiVersion = VK_MAKE_VERSION( 1, 0, 0 );    // The version of Vulkan we're using

	VkInstanceCreateInfo instanceInfo = {};
	instanceInfo.sType = VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO;
	instanceInfo.pApplicationInfo = &applicationInfo;

	const char *wantedLayers[] = {
		  "VK_LAYER_LUNARG_standard_validation"
		, "VK_LAYER_RENDERDOC_Capture"
		, "VK_LAYER_NV_nomad"
	};

	std::vector<const char*> enabledLayers;
	for ( uint iWantedLayer = 0; iWantedLayer < ARRAY_COUNT( wantedLayers ); ++iWantedLayer )
	{
		const char *layerName = wantedLayers[iWantedLayer];
		for ( const VkLayerProperties &availableLayer : layersAvailable_ )
		{
			if ( strcmp( availableLayer.layerName, layerName ) )
			{
				enabledLayers.push_back( layerName );
			}
		}
	}

	instanceInfo.enabledLayerCount = (uint32_t)enabledLayers.size();
	instanceInfo.ppEnabledLayerNames = enabledLayers.data();

	uint32_t extensionCount = 0;
	vkEnumerateInstanceExtensionProperties( NULL, &extensionCount, NULL );
	extensionsAvailable_.resize( extensionCount );
	vkEnumerateInstanceExtensionProperties( NULL, &extensionCount, extensionsAvailable_.data() );

	std::vector<const char*> extensionsEnabled;
	for ( const VkExtensionProperties &ext : extensionsAvailable_ )
	{
		extensionsEnabled.push_back( ext.extensionName );
	}

	instanceInfo.enabledExtensionCount = (uint32_t)extensionsEnabled.size();
	instanceInfo.ppEnabledExtensionNames = extensionsEnabled.data();

	VulkanCall( vkCreateInstance( &instanceInfo, nullptr, &instance_ ) );

	volkLoadInstance( instance_ );

	VkDebugReportCallbackCreateInfoEXT callbackCreateInfo = {};
	callbackCreateInfo.sType = VK_STRUCTURE_TYPE_DEBUG_REPORT_CREATE_INFO_EXT;
	callbackCreateInfo.flags =
		VK_DEBUG_REPORT_ERROR_BIT_EXT |
		VK_DEBUG_REPORT_WARNING_BIT_EXT |
		VK_DEBUG_REPORT_PERFORMANCE_WARNING_BIT_EXT;

	callbackCreateInfo.pfnCallback = &MyDebugReportCallback;
	callbackCreateInfo.pUserData = nullptr;

	VulkanCall( vkCreateDebugReportCallbackEXT( instance_, &callbackCreateInfo, nullptr, &debugReportCallback_ ) );

	VkWin32SurfaceCreateInfoKHR surfaceCreateInfo = {};
	surfaceCreateInfo.sType = VK_STRUCTURE_TYPE_WIN32_SURFACE_CREATE_INFO_KHR;
	surfaceCreateInfo.hinstance = param.hInstance_;
	surfaceCreateInfo.hwnd = param.hWnd_;

	VulkanCall( vkCreateWin32SurfaceKHR( instance_, &surfaceCreateInfo, nullptr, &surface_ ) );

	uint32_t physicalDeviceCount = 0;
	vkEnumeratePhysicalDevices( instance_, &physicalDeviceCount, NULL );
	physicalDevicesAvailable_.resize( physicalDeviceCount );
	VulkanCall( vkEnumeratePhysicalDevices( instance_, &physicalDeviceCount, physicalDevicesAvailable_.data() ) );

	for ( uint32_t i = 0; i < physicalDeviceCount; ++i )
	{
		VkPhysicalDeviceProperties deviceProperties = {};
		vkGetPhysicalDeviceProperties( physicalDevicesAvailable_[i], &deviceProperties );

		uint32_t queueFamilyCount = 0;
		vkGetPhysicalDeviceQueueFamilyProperties( physicalDevicesAvailable_[i], &queueFamilyCount, NULL );

		//VkQueueFamilyProperties *queueFamilyProperties = new VkQueueFamilyProperties[queueFamilyCount];
		std::vector<VkQueueFamilyProperties> queueFamilyProperties;
		queueFamilyProperties.resize( queueFamilyCount );
		vkGetPhysicalDeviceQueueFamilyProperties( physicalDevicesAvailable_[i],	&queueFamilyCount, queueFamilyProperties.data() );

		for ( uint32_t j = 0; j < queueFamilyCount; ++j )
		{
			VkBool32 supportsPresent;
			vkGetPhysicalDeviceSurfaceSupportKHR( physicalDevicesAvailable_[i], j, surface_, &supportsPresent );

			if ( supportsPresent && ( queueFamilyProperties[j].queueFlags & ( VK_QUEUE_GRAPHICS_BIT | VK_QUEUE_COMPUTE_BIT ) ) )
			{
				physicalDevice_ = physicalDevicesAvailable_[i];
				physicalDeviceProperties_ = deviceProperties;
				presentQueueIdx_ = j;
				break;
			}
		}

		if ( physicalDevice_ )
		{
			break;
		}
	}

	// info for accessing one of the devices rendering queues:
	VkDeviceQueueCreateInfo queueCreateInfo = {};
	queueCreateInfo.sType = VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO;
	queueCreateInfo.queueFamilyIndex = presentQueueIdx_;
	queueCreateInfo.queueCount = 1;
	float queuePriorities[] = { 1.0f };   // ask for highest priority for our queue. (range [0,1])
	queueCreateInfo.pQueuePriorities = queuePriorities;

	VkDeviceCreateInfo deviceInfo = {};
	deviceInfo.sType = VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO;
	deviceInfo.queueCreateInfoCount = 1;
	deviceInfo.pQueueCreateInfos = &queueCreateInfo;

	//uint32_t deviceLayerCount = 0;
	//vkEnumerateDeviceLayerProperties( physicalDevice_, &deviceLayerCount, nullptr );
	//std::vector<VkLayerProperties> deviceLayersAvailable;
	//deviceLayersAvailable.resize( deviceLayerCount );
	//vkEnumerateDeviceLayerProperties( physicalDevice_, &deviceLayerCount, deviceLayersAvailable.data() );
	
	deviceInfo.enabledLayerCount = static_cast<uint32_t>( enabledLayers.size() );
	deviceInfo.ppEnabledLayerNames = enabledLayers.data();

	uint32_t deviceExtensionCount = 0;
	vkEnumerateDeviceExtensionProperties( physicalDevice_, nullptr, &deviceExtensionCount, nullptr );
	std::vector<VkExtensionProperties> deviceExtensionsAvailable;
	deviceExtensionsAvailable.resize( deviceExtensionCount );
	vkEnumerateDeviceExtensionProperties( physicalDevice_, nullptr, &deviceExtensionCount, deviceExtensionsAvailable.data() );

	std::vector<const char*> deviceExtensionsEnabled;
	for ( const VkExtensionProperties &ext : deviceExtensionsAvailable )
	{
		deviceExtensionsEnabled.push_back( ext.extensionName );
	}
	//const char *deviceExtensions[] = { "VK_KHR_swapchain" };
	deviceInfo.enabledExtensionCount = static_cast<uint32_t>( deviceExtensionsEnabled.size() );
	deviceInfo.ppEnabledExtensionNames = deviceExtensionsEnabled.data();

	//VkPhysicalDeviceFeatures features = {};
	//features.shaderClipDistance = VK_TRUE;
	//deviceInfo.pEnabledFeatures = &features;
	deviceInfo.pEnabledFeatures = nullptr;

	VulkanCall( vkCreateDevice( physicalDevice_, &deviceInfo, nullptr, &device_ ) );

	uint32_t formatCount = 0;
	vkGetPhysicalDeviceSurfaceFormatsKHR( physicalDevice_, surface_, &formatCount, nullptr );
	std::vector<VkSurfaceFormatKHR> surfaceFormats;
	surfaceFormats.resize( formatCount );
	vkGetPhysicalDeviceSurfaceFormatsKHR( physicalDevice_, surface_, &formatCount, surfaceFormats.data() );

	// If the format list includes just one entry of VK_FORMAT_UNDEFINED, the surface has
	// no preferred format. Otherwise, at least one supported format will be returned.
	VkFormat colorFormat;
	if ( formatCount == 1 && surfaceFormats[0].format == VK_FORMAT_UNDEFINED ) {
		colorFormat = VK_FORMAT_B8G8R8_UNORM;
	}
	else {
		colorFormat = surfaceFormats[0].format;
	}
	VkColorSpaceKHR colorSpace;
	colorSpace = surfaceFormats[0].colorSpace;


	VkSurfaceCapabilitiesKHR surfaceCapabilities = {};
	vkGetPhysicalDeviceSurfaceCapabilitiesKHR( physicalDevice_, surface_, &surfaceCapabilities );

	// we are effectively looking for double-buffering:
	// if surfaceCapabilities.maxImageCount == 0 there is actually no limit on the number of images! 
	uint32_t desiredImageCount = 2;
	if ( desiredImageCount < surfaceCapabilities.minImageCount )
	{
		desiredImageCount = surfaceCapabilities.minImageCount;
	}
	else if ( surfaceCapabilities.maxImageCount != 0
		&&	desiredImageCount > surfaceCapabilities.maxImageCount )
	{
		desiredImageCount = surfaceCapabilities.maxImageCount;
	}

	VkExtent2D surfaceResolution = surfaceCapabilities.currentExtent;
	if ( surfaceResolution.width == -1 )
	{
		surfaceResolution.width = backBufferWidth_;
		surfaceResolution.height = backBufferHeight_;
	}
	else
	{
		backBufferWidth_ = surfaceResolution.width;
		backBufferHeight_ = surfaceResolution.height;
	}

	VkSurfaceTransformFlagBitsKHR preTransform = surfaceCapabilities.currentTransform;
	if ( surfaceCapabilities.supportedTransforms & VK_SURFACE_TRANSFORM_IDENTITY_BIT_KHR )
	{
		preTransform = VK_SURFACE_TRANSFORM_IDENTITY_BIT_KHR;
	}

	uint32_t presentModeCount = 0;
	vkGetPhysicalDeviceSurfacePresentModesKHR( physicalDevice_, surface_, &presentModeCount, nullptr );
	std::vector<VkPresentModeKHR> presentModes;
	presentModes.resize( presentModeCount );
	vkGetPhysicalDeviceSurfacePresentModesKHR( physicalDevice_, surface_, &presentModeCount, presentModes.data() );

	VkPresentModeKHR presentationMode = VK_PRESENT_MODE_FIFO_KHR;   // always supported.
	for ( uint32_t i = 0; i < presentModeCount; ++i )
	{
		if ( presentModes[i] == VK_PRESENT_MODE_MAILBOX_KHR )
		{
			presentationMode = VK_PRESENT_MODE_MAILBOX_KHR;
			break;
		}
	}

	VkSwapchainCreateInfoKHR swapChainCreateInfo = {};
	swapChainCreateInfo.sType = VK_STRUCTURE_TYPE_SWAPCHAIN_CREATE_INFO_KHR;
	swapChainCreateInfo.surface = surface_;
	swapChainCreateInfo.minImageCount = desiredImageCount;
	swapChainCreateInfo.imageFormat = colorFormat;
	swapChainCreateInfo.imageColorSpace = colorSpace;
	swapChainCreateInfo.imageExtent = surfaceResolution;
	swapChainCreateInfo.imageArrayLayers = 1;
	swapChainCreateInfo.imageUsage = VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT;
	swapChainCreateInfo.imageSharingMode = VK_SHARING_MODE_EXCLUSIVE;   // <--
	swapChainCreateInfo.preTransform = preTransform;
	swapChainCreateInfo.compositeAlpha = VK_COMPOSITE_ALPHA_OPAQUE_BIT_KHR;
	swapChainCreateInfo.presentMode = presentationMode;
	swapChainCreateInfo.clipped = true;     // If we want clipping outside the extents
											// (remember our device features?)

	VulkanCall( vkCreateSwapchainKHR( device_, &swapChainCreateInfo, nullptr, &swapChain_ ) );

	vkGetDeviceQueue( device_, presentQueueIdx_, 0, &presentQueue_ );

	VkCommandPoolCreateInfo commandPoolCreateInfo = {};
	commandPoolCreateInfo.sType = VK_STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO;
	commandPoolCreateInfo.flags = VK_COMMAND_POOL_CREATE_RESET_COMMAND_BUFFER_BIT;
	commandPoolCreateInfo.queueFamilyIndex = presentQueueIdx_;

	VkCommandPool commandPool;
	VulkanCall( vkCreateCommandPool( device_, &commandPoolCreateInfo, nullptr, &commandPool ) );

	VkCommandBufferAllocateInfo commandBufferAllocationInfo = {};
	commandBufferAllocationInfo.sType = VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO;
	commandBufferAllocationInfo.commandPool = commandPool;
	commandBufferAllocationInfo.level = VK_COMMAND_BUFFER_LEVEL_PRIMARY;
	commandBufferAllocationInfo.commandBufferCount = 1;

	VulkanCall( vkAllocateCommandBuffers( device_, &commandBufferAllocationInfo, &setupCmdBuffer_ ) );
	VulkanCall( vkAllocateCommandBuffers( device_, &commandBufferAllocationInfo, &drawCmdBuffer_ ) );

	return true;
}


void Vulkan::ShutDown()
{
	if ( instance_ )
	{
		if ( swapChain_ )
		{
			vkDestroySwapchainKHR( device_, swapChain_, nullptr );
			swapChain_ = nullptr;
		}

		if ( device_ )
		{
			vkDestroyDevice( device_, nullptr );
			device_ = nullptr;
		}

		physicalDevice_ = nullptr;
		physicalDeviceProperties_ = {};
		presentQueueIdx_ = 0xffffffff;

		if ( surface_ )
		{
			vkDestroySurfaceKHR( instance_, surface_, nullptr );
			surface_ = nullptr;
		}

		if ( debugReportCallback_ )
		{
			vkDestroyDebugReportCallbackEXT( instance_, debugReportCallback_, nullptr );
			debugReportCallback_ = nullptr;
		}

		vkDestroyInstance( instance_, nullptr );
	}
}

} // namespace spad
