#include "AppBase_pch.h"
#include "AppBase.h"
#include "Input.h"
#include <Gfx\DebugDraw.h>
#include <Util\FileIO.h>
#include <Imgui\imgui_include.h>

IMGUI_IMPL_API LRESULT  ImGui_ImplWin32_WndProcHandler( HWND hWnd, UINT msg, WPARAM wParam, LPARAM lParam );

namespace spad
{

AppBase* AppBase::instance_;

	bool AppBase::StartUpBase( const Param& param )
	{
		appName_ = param.appName;
		instance_ = this;

		hThisInst_ = GetModuleHandle( NULL );

		WNDCLASS wincl;
		ZeroMemory( &wincl, sizeof( WNDCLASS ) );
		wincl.hInstance = hThisInst_;
		wincl.lpszClassName = appName_.c_str();
		wincl.lpfnWndProc = WinProcStatic;
		wincl.style = CS_HREDRAW | CS_VREDRAW;// | CS_OWNDC | CS_DBLCLKS;;
		wincl.hIcon = LoadIcon( hThisInst_, IDI_APPLICATION );
		wincl.hCursor = LoadCursor( hThisInst_, IDC_CROSS );
		wincl.lpszMenuName = NULL;
		wincl.cbClsExtra = 0;
		wincl.cbWndExtra = 0;
		wincl.hbrBackground = NULL;

		if ( !RegisterClass( &wincl ) )
		{
			return false;
		}

		RECT client;
		client.left = 0;
		client.top = 0;
		client.right = param.windowWidth;
		client.bottom = param.windowHeight;

		BOOL ret = AdjustWindowRectEx( &client, WS_OVERLAPPEDWINDOW, FALSE, 0 );
		(void)ret;

		hWnd_ = CreateWindow( appName_.c_str(), appName_.c_str(), WS_OVERLAPPEDWINDOW, 0, 0, client.right - client.left, client.bottom - client.top,
			nullptr, nullptr, hThisInst_, NULL );

		if ( hWnd_ == nullptr )
			return false;

		if ( param.apiType_ == APIType::Dx11 )
		{
			Dx11::Param dx11Param;
			dx11Param.hWnd = hWnd_;
			dx11Param.backBufferWidth_ = param.windowWidth;
			dx11Param.backBufferHeight_ = param.windowHeight;
			dx11Param.debugDevice = param.debugDxDevice_;
			dx11_ = std::make_unique<Dx11>();
			bool res = dx11_->StartUp( dx11Param );
			if ( !res )
				return false;
		}
		else
		{
			SPAD_ASSERT( param.apiType_ == APIType::Vulkan );
			Vulkan::Param apiParam;
			apiParam.hWnd_ = hWnd_;
			apiParam.hInstance_ = hThisInst_;
			apiParam.backBufferWidth_ = param.windowWidth;
			apiParam.backBufferHeight_ = param.windowHeight;
			apiParam.debugDevice = param.debugDxDevice_;
			vulkan_ = std::make_unique<Vulkan>();
			bool res = vulkan_->StartUp( apiParam );
			if ( !res )
				return false;
		}

		debugDraw::DontTouchThis::Initialize( dx11_->getDevice() );

		StartUpImgui();

		return true;
	}

	LRESULT CALLBACK AppBase::WinProcStatic( HWND hwnd, UINT message, WPARAM wParam, LPARAM lParam )
	{
		if ( ImGui_ImplWin32_WndProcHandler( hwnd, message, wParam, lParam ) )
			return true;

		return instance_->WinProc( hwnd, message, wParam, lParam );
	}

	LRESULT AppBase::WinProc( HWND hwnd, UINT message, WPARAM wParam, LPARAM lParam )
	{
		bool imguiWantsCaptureMouse = false;

		if ( ImGui::GetCurrentContext() )
		{
			ImGuiIO& io = ImGui::GetIO();
			imguiWantsCaptureMouse = io.WantCaptureMouse;
		}

		switch ( message )
		{
		case WM_DESTROY:
			continueLoop_ = false;
			PostQuitMessage( 0 );
			break;

		case WM_KEYUP:
		{
			if ( wParam < 256 )
			{
				keysDown_[wParam] = false;
				//SHORT ctrlDown = GetAsyncKeyState( VK_CONTROL );
				//SHORT lshiftDown = GetAsyncKeyState( VK_LSHIFT );
			}
			return 0;
		}
		case WM_KEYDOWN:
		{
			if ( wParam < 256 )
			{
				if ( keysDown_[wParam] == false )
				{
					KeyPressed( static_cast<uint>(wParam), false, false, false );
				}

				keysDown_[wParam] = true;
				//SHORT ctrlDown = GetAsyncKeyState( VK_CONTROL );
				//SHORT lshiftDown = GetAsyncKeyState( VK_LSHIFT );
			}

			//switch ( wParam )
			//{
			//case VK_ESCAPE:
			//{
			//	picoLogInfoNoLocation( "\nESC PRESSED!\n" );
			//	destroyNotify_ = true;
			//	PostQuitMessage( 0 );
			//	return 0;
			//}
			//};

			return 0;
		}

		case WM_LBUTTONDOWN:
		{
			if ( !imguiWantsCaptureMouse )
			{
				mouseLDown_ = true;
				mouseX_ = mousePrevX_ = LOWORD( lParam );
				mouseY_ = mousePrevY_ = HIWORD( lParam );
			}
			else
			{
				mouseLDown_ = false;
			}
			return 0;
		}

		case WM_LBUTTONUP:
		{
			mouseLDown_ = false;
			return 0;
		}

		case WM_MOUSEMOVE:
		{
			if ( mouseLDown_ && !imguiWantsCaptureMouse )
			{
				//mousePrevX_ = mouseX_;
				//mousePrevY_ = mouseY_;
				mouseX_ = LOWORD( lParam );
				mouseY_ = HIWORD( lParam );
			}
			return 0;
		}

		default:
			return DefWindowProc( hwnd, message, wParam, lParam );
		};

		return 0;
	}

	void AppBase::ShutDownBase()
	{
		ShutDownImgui();

		debugDraw::DontTouchThis::DeInitialize();

		dx11_.reset();
		vulkan_.reset();

		if ( hWnd_ != nullptr )
		{
			DestroyWindow( hWnd_ );
			hWnd_ = nullptr;
		}

		if ( hThisInst_ && !appName_.empty() )
		{
			UnregisterClass( appName_.c_str(), hThisInst_ );
		}

		hThisInst_ = nullptr;
		appName_.clear();
	}

	void AppBase::Loop()
	{
		ShowWindow( hWnd_, SW_SHOW );
		UpdateWindow( hWnd_ );

		MSG msg;
		msg.wParam = 0;

		for( ;; )
		{
			while ( PeekMessage( &msg, hWnd_, 0, 0, PM_REMOVE ) )
			{
				TranslateMessage( &msg );
				DispatchMessage( &msg );
			}

			// Start the Dear ImGui frame
			ImGui_ImplDX11_NewFrame();
			ImGui_ImplWin32_NewFrame();
			ImGui::NewFrame();

			if ( !continueLoop_ )
				break;

			timer_.Update();

			UpdateAndRender( timer_ );

			// Imgui
			DrawImGui();
			ImGui::Render();
			ImGui_ImplDX11_RenderDrawData( ImGui::GetDrawData() );

			dx11_->Present( 0 );
		}
	}

	void AppBase::StartUpImgui()
	{
		// Setup Dear ImGui context
		IMGUI_CHECKVERSION();
		ImGui::CreateContext();
		ImGuiIO& io = ImGui::GetIO(); (void)io;
		//io.ConfigFlags |= ImGuiConfigFlags_NavEnableKeyboard;  // Enable Keyboard Controls

		// Setup Platform/Renderer bindings
		ImGui_ImplWin32_Init( hWnd_ );
		ImGui_ImplDX11_Init( dx11_->getDevice(), dx11_->getImmediateContext() );

		// Setup Style
		ImGui::StyleColorsDark();
		//ImGui::StyleColorsClassic();
	}

	void AppBase::ShutDownImgui()
	{
		ImGui_ImplDX11_Shutdown();
		ImGui_ImplWin32_Shutdown();
		ImGui::DestroyContext();
	}

	void AppBase::DrawImGui()
	{
		//static float f = 0.0f;
		//static int counter = 0;

		ImGui::Begin( "Scratchpad" );                          // Create a window called "Hello, world!" and append into it.

		//ImGui::Text( "This is some useful text." );               // Display some text (you can use a format strings too)
		//ImGui::Checkbox( "Demo Window", &show_demo_window );      // Edit bools storing our window open/close state
		//ImGui::Checkbox( "Another Window", &show_another_window );

		//ImGui::SliderFloat( "float", &f, 0.0f, 1.0f );            // Edit 1 float using a slider from 0.0f to 1.0f    
		//ImGui::ColorEdit3( "clear color", (float*)&clear_color ); // Edit 3 floats representing a color

		//if ( ImGui::Button( "Button" ) )                            // Buttons return true when clicked (most widgets return true when edited/activated)
		//	counter++;
		//ImGui::SameLine();
		//ImGui::Text( "counter = %d", counter );

		ImGui::Text( "Application average %.3f ms/frame (%.1f FPS)", 1000.0f / ImGui::GetIO().Framerate, ImGui::GetIO().Framerate );

		UpdateImGui( timer_ );

		ImGui::End();
	}

	void AppBase::UpdateCamera( Matrix4 &worldMatrix, float deltaTimeSec )
	{
		const float dt = deltaTimeSec;

		//MouseState mouseState = MouseState::GetMouseState( hWnd_ );
		//KeyboardState kbState = KeyboardState::GetKeyboardState( hWnd_ );

		floatInVec CamMoveSpeed( 10.0f * dt );
		floatInVec CamRotSpeed( 10.0f * dt );

		// Move the camera with keyboard input
		if ( IsKeyDown( KeyboardState::LeftShift ) )
		{
			CamMoveSpeed *= floatInVec( 0.25f );
			CamRotSpeed *= floatInVec( 0.25f );
		}

		Matrix4 world = worldMatrix;
		floatInVec deltaTime( dt );

		if ( IsKeyDown( KeyboardState::W ) )
		{
			Vector3 dir = world.getCol2().getXYZ();
			Vector3 offs = dir * -CamMoveSpeed;
			world.setTranslation( world.getTranslation() + offs );
		}
		if ( IsKeyDown( KeyboardState::S ) )
		{
			Vector3 dir = world.getCol2().getXYZ();
			Vector3 offs = dir * CamMoveSpeed;
			world.setTranslation( world.getTranslation() + offs );
		}
		if ( IsKeyDown( KeyboardState::A ) )
		{
			Vector3 dir = world.getCol0().getXYZ();
			Vector3 offs = dir * -CamMoveSpeed;
			world.setTranslation( world.getTranslation() + offs );
		}
		if ( IsKeyDown( KeyboardState::D ) )
		{
			Vector3 dir = world.getCol0().getXYZ();
			Vector3 offs = dir * CamMoveSpeed;
			world.setTranslation( world.getTranslation() + offs );
		}
		if ( IsKeyDown( KeyboardState::Q ) )
		{
			Vector3 dir = world.getCol1().getXYZ();
			Vector3 offs = dir * CamMoveSpeed;
			world.setTranslation( world.getTranslation() + offs );
		}
		if ( IsKeyDown( KeyboardState::Z ) )
		{
			Vector3 dir = world.getCol1().getXYZ();
			Vector3 offs = dir * -CamMoveSpeed;
			world.setTranslation( world.getTranslation() + offs );
		}

		int mouseDx = mouseX_ - mousePrevX_;
		int mouseDy = mouseY_ - mousePrevY_;
		mousePrevX_ = mouseX_;
		mousePrevY_ = mouseY_;

		//if ( mouseState.LButton.Pressed && ( mouseState.DX != 0 || mouseState.DY != 0 ) )
		if ( mouseLDown_ && ( mouseDx != 0 || mouseDy != 0 ) )
		{
			Quat rot = normalize( Quat( world.getUpper3x3() ) );

			floatInVec deltaX = floatInVec( (float)mouseDx );
			floatInVec deltaY = floatInVec( (float)mouseDy );

			deltaX *= floatInVec( PI / 180.0f ) * CamRotSpeed;
			deltaY *= floatInVec( PI / 180.0f ) * CamRotSpeed;

			Quat rotY = Quat::rotationY( -deltaX );
			Quat rotX = Quat::rotation( -deltaY, world.getCol0().getXYZ() );
			Quat rotOffs = rotY * rotX;
			Quat newRot = rotOffs * rot;
			newRot = normalize( newRot );

			Matrix3 newOrient = Matrix3( newRot );
			world.setUpper3x3( newOrient );
		}

		worldMatrix = world;
	}

} // namespace spad
