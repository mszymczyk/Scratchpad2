#pragma once

#include <Gfx\Dx11\Dx11.h>
#include <Gfx\Vulkan\Vulkan.h>
#include <Util\Timer.h>
#include <Util\Vectormath.h>
#include "Input.h"

namespace spad
{

	class AppBase
	{
	public:
		~AppBase()
		{
			ShutDownBase();
		}

		enum class APIType
		{
			Dx11,
			Vulkan,
			Count
		};

		struct Param
		{
			const char* appName = nullptr;
			u32 windowWidth = 1280;
			u32 windowHeight = 720;
			//u32 windowWidth = 1024;
			//u32 windowHeight = 1024;
			bool debugDxDevice_ = false;
			APIType apiType_ = APIType::Dx11;
		};

		bool StartUpBase( const Param& param );

	private:
		void ShutDownBase();
	public:

		void Loop();

		virtual void UpdateAndRender( const Timer& timer )
		{
			(void)timer;
		}

		virtual void UpdateImGui( const Timer& timer )
		{
			(void)timer;
		}

		virtual void KeyPressed( uint key, bool shift, bool alt, bool ctrl )
		{
			(void)key;
			(void)shift;
			(void)alt;
			(void)ctrl;
		}

	private:
		static LRESULT CALLBACK WinProcStatic( HWND hwnd, UINT message, WPARAM wParam, LPARAM lParam );
		LRESULT WinProc( HWND hwnd, UINT message, WPARAM wParam, LPARAM lParam );

		void StartUpImgui();
		void ShutDownImgui();
		void DrawImGui();

	protected:
		void UpdateCamera( Matrix4 &worldMatrix, float deltaTime );

		bool IsKeyDown( KeyboardState::Keys key ) const
		{
			assert( key < 256 );
			return keysDown_[key];
		}

	protected:
		std::string appName_;
		HINSTANCE hThisInst_ = nullptr;
		HWND hWnd_ = nullptr;
		bool continueLoop_ = true;

		bool keysDown_[256] = { false };
		bool mouseLDown_ = false;
		int mouseX_ = 0, mouseY_ = 0;
		int mousePrevX_ = 0, mousePrevY_ = 0;

		Timer timer_;

		std::unique_ptr<Dx11> dx11_;
		std::unique_ptr<Vulkan> vulkan_;

		static AppBase* instance_;
	};

} // namespace spad