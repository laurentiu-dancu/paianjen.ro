// See the Tailwind guide for customization: https://tailwindcss.com/docs/configuration

module.exports = {
  content: [
    "./js/**/*.js",
    "../lib/paianjen_web.ex",
    "../lib/paianjen_web/**/*.*ex",
    "../lib/paianjen_web/**/*.heex",
    "../lib/paianjen_web/**/*.html.heex",
  ],
  theme: {
    extend: {
      fontFamily: {
        sans: ["Inter", "system-ui", "-apple-system", "sans-serif"],
      },
    },
  },
  plugins: [],
};
