# EchoTune Website

Award-winning marketing website for EchoTune - AI Voice to Text for Mac.

## Features

- **Modern Design**: Clean, minimal, award-winning aesthetic
- **Dark/Light Theme**: Automatic system preference detection + manual toggle
- **Fully Responsive**: Works on all devices from mobile to desktop
- **Fast Loading**: No frameworks, pure HTML/CSS/JS
- **SEO Optimized**: Proper meta tags, semantic HTML
- **Accessible**: ARIA labels, keyboard navigation, proper contrast

## Pages

- `index.html` - Main landing page with features, pricing, FAQ
- `privacy.html` - Privacy policy (compliant, plain-language)
- `terms.html` - Terms of service
- `support.html` - Support page with troubleshooting guides

## Deployment

### Option 1: Netlify (Recommended)

1. Push to GitHub
2. Connect to Netlify
3. Set build command: `(none)` (static site)
4. Set publish directory: `website`
5. Deploy!

### Option 2: Vercel

1. Install Vercel CLI: `npm i -g vercel`
2. Run `vercel` in the website directory
3. Follow prompts

### Option 3: GitHub Pages

1. Go to repo Settings → Pages
2. Set source to `main` branch, `/website` folder
3. Save and wait for deployment

### Option 4: Any Static Host

Upload the contents of this folder to any web server or CDN.

## Customization

### Colors

Edit CSS custom properties in `styles.css`:

```css
:root {
    --color-primary: #6366f1;
    --color-accent: #8b5cf6;
    /* ... */
}
```

### Content

All content is in plain HTML. Edit `index.html` to update:
- Hero text
- Features
- Pricing
- FAQ

### Theme

The site automatically detects system preference. Users can toggle manually.
Theme preference is saved to localStorage.

## File Structure

```
website/
├── index.html          # Main landing page
├── privacy.html        # Privacy policy
├── terms.html          # Terms of service
├── support.html        # Support & troubleshooting
├── styles.css          # All styles (light + dark themes)
├── script.js           # Interactive features
├── favicon-16.png      # Favicon (16x16)
├── favicon-32.png      # Favicon (32x32)
├── apple-touch-icon.png # iOS icon
└── README.md           # This file
```

## Performance

- No JavaScript frameworks (vanilla JS only)
- No external CSS frameworks
- Minimal dependencies (only Google Fonts)
- CSS is optimized with custom properties
- Images should be optimized before adding

## Browser Support

- Chrome 90+
- Firefox 88+
- Safari 14+
- Edge 90+

## License

This website is part of the EchoTune project.
© 2025 EchoTune Software. All rights reserved.
