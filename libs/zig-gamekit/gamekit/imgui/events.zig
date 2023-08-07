const std = @import("std");
const imgui = @import("imgui");
const sdl = @import("sdl");
const gk = @import("../gamekit.zig");

pub const Events = struct {
    mouse_cursors: [imgui.ImGuiMouseCursor_COUNT]?*sdl.SDL_Cursor = undefined,
    mouse_button_state: [4]bool = undefined,
    global_time: u64 = 0,

    var clipboard_text: [*c]u8 = null;

    pub fn init() Events {
        var io = imgui.igGetIO();
        io.BackendFlags |= imgui.ImGuiBackendFlags_HasMouseCursors;
        io.BackendFlags |= imgui.ImGuiBackendFlags_HasSetMousePos;

        io.KeyMap[imgui.ImGuiKey_Tab] = @intFromEnum(sdl.SDL_Scancode.SDL_SCANCODE_TAB);
        io.KeyMap[imgui.ImGuiKey_LeftArrow] = @intFromEnum(sdl.SDL_Scancode.SDL_SCANCODE_LEFT);
        io.KeyMap[imgui.ImGuiKey_RightArrow] = @intFromEnum(sdl.SDL_Scancode.SDL_SCANCODE_RIGHT);
        io.KeyMap[imgui.ImGuiKey_UpArrow] = @intFromEnum(sdl.SDL_Scancode.SDL_SCANCODE_UP);
        io.KeyMap[imgui.ImGuiKey_DownArrow] = @intFromEnum(sdl.SDL_Scancode.SDL_SCANCODE_DOWN);
        io.KeyMap[imgui.ImGuiKey_PageUp] = @intFromEnum(sdl.SDL_Scancode.SDL_SCANCODE_PAGEUP);
        io.KeyMap[imgui.ImGuiKey_PageDown] = @intFromEnum(sdl.SDL_Scancode.SDL_SCANCODE_PAGEDOWN);
        io.KeyMap[imgui.ImGuiKey_Home] = @intFromEnum(sdl.SDL_Scancode.SDL_SCANCODE_HOME);
        io.KeyMap[imgui.ImGuiKey_End] = @intFromEnum(sdl.SDL_Scancode.SDL_SCANCODE_END);
        io.KeyMap[imgui.ImGuiKey_Insert] = @intFromEnum(sdl.SDL_Scancode.SDL_SCANCODE_INSERT);
        io.KeyMap[imgui.ImGuiKey_Delete] = @intFromEnum(sdl.SDL_Scancode.SDL_SCANCODE_DELETE);
        io.KeyMap[imgui.ImGuiKey_Backspace] = @intFromEnum(sdl.SDL_Scancode.SDL_SCANCODE_BACKSPACE);
        io.KeyMap[imgui.ImGuiKey_Space] = @intFromEnum(sdl.SDL_Scancode.SDL_SCANCODE_SPACE);
        io.KeyMap[imgui.ImGuiKey_Enter] = @intFromEnum(sdl.SDL_Scancode.SDL_SCANCODE_RETURN);
        io.KeyMap[imgui.ImGuiKey_Escape] = @intFromEnum(sdl.SDL_Scancode.SDL_SCANCODE_ESCAPE);
        io.KeyMap[imgui.ImGuiKey_KeyPadEnter] = @intFromEnum(sdl.SDL_Scancode.SDL_SCANCODE_RETURN2);
        io.KeyMap[imgui.ImGuiKey_A] = @intFromEnum(sdl.SDL_Scancode.SDL_SCANCODE_A);
        io.KeyMap[imgui.ImGuiKey_C] = @intFromEnum(sdl.SDL_Scancode.SDL_SCANCODE_C);
        io.KeyMap[imgui.ImGuiKey_V] = @intFromEnum(sdl.SDL_Scancode.SDL_SCANCODE_V);
        io.KeyMap[imgui.ImGuiKey_X] = @intFromEnum(sdl.SDL_Scancode.SDL_SCANCODE_X);
        io.KeyMap[imgui.ImGuiKey_Y] = @intFromEnum(sdl.SDL_Scancode.SDL_SCANCODE_Y);
        io.KeyMap[imgui.ImGuiKey_Z] = @intFromEnum(sdl.SDL_Scancode.SDL_SCANCODE_Z);

        io.SetClipboardTextFn = setClipboardTextFn;
        io.GetClipboardTextFn = getClipboardTextFn;

        var self = Events{};
        self.mouse_cursors[@as(usize, @intCast(imgui.ImGuiMouseCursor_Arrow))] = sdl.SDL_CreateSystemCursor(sdl.SDL_SystemCursor.SDL_SYSTEM_CURSOR_ARROW);
        self.mouse_cursors[@as(usize, @intCast(imgui.ImGuiMouseCursor_TextInput))] = sdl.SDL_CreateSystemCursor(sdl.SDL_SystemCursor.SDL_SYSTEM_CURSOR_IBEAM);
        self.mouse_cursors[@as(usize, @intCast(imgui.ImGuiMouseCursor_ResizeAll))] = sdl.SDL_CreateSystemCursor(sdl.SDL_SystemCursor.SDL_SYSTEM_CURSOR_SIZEALL);
        self.mouse_cursors[@as(usize, @intCast(imgui.ImGuiMouseCursor_ResizeNS))] = sdl.SDL_CreateSystemCursor(sdl.SDL_SystemCursor.SDL_SYSTEM_CURSOR_SIZENS);
        self.mouse_cursors[@as(usize, @intCast(imgui.ImGuiMouseCursor_ResizeEW))] = sdl.SDL_CreateSystemCursor(sdl.SDL_SystemCursor.SDL_SYSTEM_CURSOR_SIZEWE);
        self.mouse_cursors[@as(usize, @intCast(imgui.ImGuiMouseCursor_ResizeNESW))] = sdl.SDL_CreateSystemCursor(sdl.SDL_SystemCursor.SDL_SYSTEM_CURSOR_SIZENESW);
        self.mouse_cursors[@as(usize, @intCast(imgui.ImGuiMouseCursor_ResizeNWSE))] = sdl.SDL_CreateSystemCursor(sdl.SDL_SystemCursor.SDL_SYSTEM_CURSOR_SIZENWSE);
        self.mouse_cursors[@as(usize, @intCast(imgui.ImGuiMouseCursor_Hand))] = sdl.SDL_CreateSystemCursor(sdl.SDL_SystemCursor.SDL_SYSTEM_CURSOR_HAND);
        self.mouse_cursors[@as(usize, @intCast(imgui.ImGuiMouseCursor_NotAllowed))] = sdl.SDL_CreateSystemCursor(sdl.SDL_SystemCursor.SDL_SYSTEM_CURSOR_NO);

        // TODO: ImGui_ImplSDL2_UpdateMonitors

        // TODO: ImGui_ImplSDL2_InitPlatformInterface
        if ((io.ConfigFlags & imgui.ImGuiConfigFlags_ViewportsEnable) != 0 and (io.BackendFlags & imgui.ImGuiBackendFlags_PlatformHasViewports) != 0) {
            // var main_vp = imgui.igGetMainViewport();
            // main_vp.PlatformHandle = window;
            //init_platform_interface(window);
        }

        return self;
    }

    pub fn deinit(self: Events) void {
        if (clipboard_text) |txt| sdl.SDL_free(txt);

        // Destroy SDL mouse cursors
        for (self.mouse_cursors) |cursor| {
            sdl.SDL_FreeCursor(cursor);
        }
    }

    fn getClipboardTextFn(ctx: ?*anyopaque) callconv(.C) [*c]const u8 {
        _ = ctx;
        if (clipboard_text) |txt| {
            sdl.SDL_free(txt);
            clipboard_text = null;
        }
        clipboard_text = sdl.SDL_GetClipboardText();
        return clipboard_text;
    }

    fn setClipboardTextFn(ctx: ?*anyopaque, text: [*c]const u8) callconv(.C) void {
        _ = ctx;
        _ = sdl.SDL_SetClipboardText(text);
    }

    pub fn newFrame(
        self: *Events,
        window: *sdl.SDL_Window,
    ) void {
        var win_size = gk.window.size();
        var drawable_size = gk.window.drawableSize();

        const io = imgui.igGetIO();
        io.DisplaySize = imgui.ImVec2{ .x = @as(f32, @floatFromInt(win_size.w)), .y = @as(f32, @floatFromInt(win_size.h)) };

        if (win_size.w > 0 and win_size.h > 0) {
            io.DisplayFramebufferScale = imgui.ImVec2{
                .x = @as(f32, @floatFromInt(drawable_size.w)) / @as(f32, @floatFromInt(win_size.w)),
                .y = @as(f32, @floatFromInt(drawable_size.h)) / @as(f32, @floatFromInt(win_size.h)),
            };
        }

        const frequency = sdl.SDL_GetPerformanceFrequency();
        const current_time = sdl.SDL_GetPerformanceCounter();
        io.DeltaTime = if (self.global_time > 0) @as(f32, @floatCast((@as(f64, @floatFromInt(current_time - self.global_time))) / @as(f64, @floatFromInt(frequency)))) else @as(f32, 1 / 60);
        self.global_time = current_time;

        // ImGui_ImplSDL2_UpdateMousePosAndButtons
        if (io.WantSetMousePos) {
            if ((io.ConfigFlags & imgui.ImGuiConfigFlags_ViewportsEnable) != 0) {
                _ = sdl.SDL_WarpMouseGlobal(@as(c_int, @intFromFloat(io.MousePos.x)), @as(c_int, @intFromFloat(io.MousePos.y)));
            } else {
                _ = sdl.SDL_WarpMouseInWindow(window, @as(c_int, @intFromFloat(io.MousePos.x)), @as(c_int, @intFromFloat(io.MousePos.y)));
            }
        }

        // Set Dear ImGui mouse pos from OS mouse pos + get buttons. (this is the common behavior)
        var mouse_x_local: c_int = undefined;
        var mouse_y_local: c_int = undefined;
        const mouse_buttons = sdl.SDL_GetMouseState(&mouse_x_local, &mouse_y_local);
        io.MouseDown[0] = self.mouse_button_state[0] or sdlButton(mouse_buttons, 1);
        io.MouseDown[1] = self.mouse_button_state[1] or sdlButton(mouse_buttons, 3);
        io.MouseDown[2] = self.mouse_button_state[2] or sdlButton(mouse_buttons, 2);

        self.mouse_button_state[0] = false;
        self.mouse_button_state[1] = false;
        self.mouse_button_state[2] = false;

        var mouse_x_global: c_int = undefined;
        var mouse_y_global: c_int = undefined;
        _ = sdl.SDL_GetGlobalMouseState(&mouse_x_global, &mouse_y_global);

        if (io.ConfigFlags & imgui.ImGuiConfigFlags_ViewportsEnable != 0) {
            std.log.warn("viewports not implemented\n", .{});
        } else if (sdl.SDL_GetWindowFlags(window) | @as(u32, @intCast(@intFromEnum(sdl.SDL_WindowFlags.SDL_WINDOW_INPUT_FOCUS))) != 1) {
            var win_x: i32 = undefined;
            var win_y: i32 = undefined;
            sdl.SDL_GetWindowPosition(window, &win_x, &win_y);
            io.MousePos = imgui.ImVec2{
                .x = @as(f32, @floatFromInt(mouse_x_global - win_x)),
                .y = @as(f32, @floatFromInt(mouse_y_global - win_y)),
            };
        }

        // ImGui_ImplSDL2_UpdateMouseCursor
        if (io.ConfigFlags & imgui.ImGuiConfigFlags_NoMouseCursorChange == 0) {
            const cursor = imgui.igGetMouseCursor();
            if (io.MouseDrawCursor or cursor == imgui.ImGuiMouseCursor_None) {
                _ = sdl.SDL_ShowCursor(sdl.SDL_FALSE);
            } else {
                sdl.SDL_SetCursor(self.mouse_cursors[@as(usize, @intCast(cursor))] orelse self.mouse_cursors[@as(usize, @intCast(imgui.ImGuiMouseCursor_Arrow))].?);
                _ = sdl.SDL_ShowCursor(sdl.SDL_TRUE);
            }
        }

        // TODO: ImGui_ImplSDL2_UpdateGamepads
    }

    // Mimics the SDL_BUTTON macro and does the button down check
    fn sdlButton(mouse_buttons: u32, comptime button: u32) bool {
        return mouse_buttons & (1 << (button - 1)) != 0;
    }

    pub fn handleEvent(self: *Events, event: *sdl.SDL_Event) bool {
        switch (event.type) {
            sdl.SDL_MOUSEWHEEL => {
                const io = imgui.igGetIO();
                if (event.wheel.x > 0) io.MouseWheelH -= 1;
                if (event.wheel.x < 0) io.MouseWheelH += 1;
                if (event.wheel.y > 0) io.MouseWheel += 1;
                if (event.wheel.y < 0) io.MouseWheel -= 1;
                return io.WantCaptureMouse;
            },
            sdl.SDL_MOUSEBUTTONDOWN => {
                const io = imgui.igGetIO();
                if (event.button.button == 1) self.mouse_button_state[0] = true;
                if (event.button.button == 2) self.mouse_button_state[1] = true;
                if (event.button.button == 3) self.mouse_button_state[2] = true;
                return io.WantCaptureMouse;
            },
            sdl.SDL_TEXTINPUT => {
                const io = imgui.igGetIO();
                imgui.ImGuiIO_AddInputCharactersUTF8(io, &event.text.text[0]);
                return io.WantCaptureKeyboard;
            },
            sdl.SDL_KEYDOWN, sdl.SDL_KEYUP => {
                const io = imgui.igGetIO();
                const mod_state = @intFromEnum(sdl.SDL_GetModState());
                io.KeysDown[@as(usize, @intCast(@intFromEnum(event.key.keysym.scancode)))] = event.type == sdl.SDL_KEYDOWN;
                io.KeyShift = (mod_state & @intFromEnum(sdl.SDL_Keymod.KMOD_SHIFT)) != 0;
                io.KeyCtrl = (mod_state & @intFromEnum(sdl.SDL_Keymod.KMOD_CTRL)) != 0;
                io.KeyAlt = (mod_state & @intFromEnum(sdl.SDL_Keymod.KMOD_ALT)) != 0;
                if (@import("builtin").target.os.tag == .windows) io.KeySuper = false else io.KeySuper = (mod_state & @intFromEnum(sdl.SDL_Keymod.KMOD_GUI)) != 0;
                return io.WantCaptureKeyboard;
            },
            sdl.SDL_WINDOWEVENT => {
                // TODO: should this return true?
                const event_type = @as(sdl.SDL_WindowEventID, @enumFromInt(event.window.event));
                if (event_type == .SDL_WINDOWEVENT_CLOSE or event_type == .SDL_WINDOWEVENT_MOVED or event_type == .SDL_WINDOWEVENT_RESIZED) {
                    if (imgui.igFindViewportByPlatformHandle(sdl.SDL_GetWindowFromID(event.window.windowID))) |viewport| {
                        if (event_type == .SDL_WINDOWEVENT_CLOSE) viewport.PlatformRequestClose = true;
                        if (event_type == .SDL_WINDOWEVENT_MOVED) viewport.PlatformRequestMove = true;
                        if (event_type == .SDL_WINDOWEVENT_RESIZED) viewport.PlatformRequestResize = true;
                    }
                }
            },
            else => {},
        }
        return false;
    }
};
