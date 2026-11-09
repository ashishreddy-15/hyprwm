-- Environment for apps started from this session.

-- Cursor: the same theme and size as GTK apps (gsettings, set by the
-- appearance menu), so the pointer matches in Hyprland, GTK and XWayland.
local function gsetting(key, fallback)
    local ok, value = pcall(function()
        local p = io.popen("gsettings get org.gnome.desktop.interface " .. key .. " 2>/dev/null")
        local v = p:read("*l")
        p:close()
        return v
    end)
    if not ok or not value or value == "" then return fallback end
    return (value:gsub("^'(.*)'$", "%1"))
end

local cursor_theme = gsetting("cursor-theme", "Adwaita")
local cursor_size  = gsetting("cursor-size", "24")

hl.env("XCURSOR_THEME", cursor_theme)
hl.env("XCURSOR_SIZE", cursor_size)
hl.env("HYPRCURSOR_THEME", cursor_theme)
hl.env("HYPRCURSOR_SIZE", cursor_size)

-- Toolkits: prefer Wayland, fall back to X11
hl.env("QT_QPA_PLATFORM", "wayland;xcb")
hl.env("QT_WAYLAND_DISABLE_WINDOWDECORATION", "1")
hl.env("GDK_BACKEND", "wayland,x11,*")
hl.env("SDL_VIDEODRIVER", "wayland,x11")
hl.env("CLUTTER_BACKEND", "wayland")
hl.env("ELECTRON_OZONE_PLATFORM_HINT", "auto")

-- Same as ~/.config/sway/environment: Java GUI apps render blank otherwise
hl.env("_JAVA_AWT_WM_NONREPARENTING", "1")

-- XDG session identity (portals pick xdg-desktop-portal-hyprland from this)
hl.env("XDG_CURRENT_DESKTOP", "Hyprland")
hl.env("XDG_SESSION_TYPE", "wayland")
hl.env("XDG_SESSION_DESKTOP", "Hyprland")
