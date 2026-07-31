/** @type {import('tailwindcss').Config} */
module.exports = {
  darkMode: "class",
  content: ["./app/**/*.{ts,tsx}", "./src/**/*.{ts,tsx}"],
  presets: [require("nativewind/preset")],
  theme: {
    extend: {
      colors: {
        // Mirrors web/src/app/globals.css's HSL tokens (converted to hex) so the
        // mobile app reads as the same storefront, not a re-skinned template.
        background: { DEFAULT: "#fbf8f3", dark: "#17130f" },
        foreground: { DEFAULT: "#211d1a", dark: "#efe9e1" },
        card: { DEFAULT: "#ffffff", dark: "#201b17" },
        primary: { DEFAULT: "#145c3f", foreground: "#fbf8f3", dark: "#2fa374" },
        secondary: { DEFAULT: "#f0eae3", foreground: "#211d1a", dark: "#2b2521" },
        muted: { DEFAULT: "#f0eae3", foreground: "#6b615a", dark: "#2b2521" },
        accent: { DEFAULT: "#d97a2e", foreground: "#211d1a", dark: "#de8a3f" },
        destructive: { DEFAULT: "#c53021", foreground: "#fbf8f3", dark: "#cc5142" },
        border: { DEFAULT: "#e2dcd3", dark: "#362f29" },
        success: "#16794f",
        warning: "#b8790a",
      },
      borderRadius: {
        lg: "12px",
        md: "10px",
        sm: "8px",
      },
    },
  },
  plugins: [],
};
