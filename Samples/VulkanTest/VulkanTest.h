#include <Core/AppBase/AppBase.h>
#include <Core/Gfx/Mesh/Model.h>
#include <shaders/hlsl/PassConstants.h>
#include <Core/Gfx/Camera.h>
#include <Core/Gfx/Text/TextRenderer.h>
#include <Core\Gfx\Dx11\Dx11Shader.h>

namespace spad
{
	class VulkanTest : public AppBase
	{
	public:
		~VulkanTest()
		{
			ShutDown();
		}

		bool StartUp();

	protected:
		void ShutDown();
		void UpdateAndRender( const Timer& timer ) override;
		void KeyPressed( uint key, bool shift, bool alt, bool ctrl ) override;
	};
}

