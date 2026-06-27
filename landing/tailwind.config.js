module.exports = {
  darkMode: 'class',
  content: ['./landing/index.html'],
  theme: {
    extend: {
      colors: {
        primary: '#db7706',
        'primary-dark': '#b45f04',
        secondary: '#15803d',
        'background-light': '#f4efea',
        'background-dark': '#231a0f',
      },
      fontFamily: {
        display: ['Proxima Nova', '-apple-system', 'BlinkMacSystemFont', 'Segoe UI', 'sans-serif'],
      },
      borderRadius: {
        DEFAULT: '0.375rem',
        lg: '0.5rem',
        xl: '0.75rem',
        '2xl': '1rem',
        '3xl': '1.5rem',
        full: '9999px',
      },
      boxShadow: {
        soft: '0 4px 20px -2px rgba(0, 0, 0, 0.05)',
        glow: '0 0 15px rgba(219, 119, 6, 0.3)',
      },
    },
  },
};
