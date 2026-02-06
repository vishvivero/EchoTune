// ========================================
// EchoTune Website - JavaScript
// ========================================

document.addEventListener('DOMContentLoaded', () => {
    initThemeToggle();
    initNavScroll();
    initTypingAnimation();
    initMobileMenu();
    initSmoothScroll();
});

// ========================================
// Theme Toggle (Light/Dark Mode)
// ========================================

function initThemeToggle() {
    const toggle = document.getElementById('theme-toggle');
    const html = document.documentElement;
    
    // Check for saved preference or system preference
    const savedTheme = localStorage.getItem('theme');
    const systemPrefersDark = window.matchMedia('(prefers-color-scheme: dark)').matches;
    
    if (savedTheme) {
        html.setAttribute('data-theme', savedTheme);
    } else if (systemPrefersDark) {
        html.setAttribute('data-theme', 'dark');
    }
    
    toggle.addEventListener('click', () => {
        const currentTheme = html.getAttribute('data-theme');
        const newTheme = currentTheme === 'dark' ? 'light' : 'dark';
        
        html.setAttribute('data-theme', newTheme);
        localStorage.setItem('theme', newTheme);
        
        // Add a subtle animation
        toggle.style.transform = 'rotate(180deg)';
        setTimeout(() => {
            toggle.style.transform = '';
        }, 300);
    });
    
    // Listen for system theme changes
    window.matchMedia('(prefers-color-scheme: dark)').addEventListener('change', (e) => {
        if (!localStorage.getItem('theme')) {
            html.setAttribute('data-theme', e.matches ? 'dark' : 'light');
        }
    });
}

// ========================================
// Navigation Scroll Effect
// ========================================

function initNavScroll() {
    const nav = document.getElementById('nav');
    let lastScroll = 0;
    
    window.addEventListener('scroll', () => {
        const currentScroll = window.pageYOffset;
        
        // Add scrolled class for border
        if (currentScroll > 50) {
            nav.classList.add('scrolled');
        } else {
            nav.classList.remove('scrolled');
        }
        
        lastScroll = currentScroll;
    });
}

// ========================================
// Typing Animation in Hero
// ========================================

function initTypingAnimation() {
    const typingText = document.getElementById('typing-text');
    if (!typingText) return;
    
    const phrases = [
        "Transform your voice into perfectly formatted text. No more typing, just speak naturally and watch your words appear exactly where you need them.",
        "Just recorded a quick memo for the team. Meeting notes done in seconds. Time saved: 15 minutes of typing.",
        "The AI enhancement feature is incredible. It fixed my grammar and removed all the 'ums' automatically.",
        "Writing this email by voice while walking to the coffee shop. EchoTune works everywhere on my Mac."
    ];
    
    let phraseIndex = 0;
    let charIndex = 0;
    let isDeleting = false;
    let isPaused = false;
    
    function type() {
        const currentPhrase = phrases[phraseIndex];
        
        if (isPaused) {
            setTimeout(type, 2000);
            isPaused = false;
            isDeleting = true;
            return;
        }
        
        if (isDeleting) {
            typingText.textContent = currentPhrase.substring(0, charIndex - 1);
            charIndex--;
            
            if (charIndex === 0) {
                isDeleting = false;
                phraseIndex = (phraseIndex + 1) % phrases.length;
                setTimeout(type, 500);
                return;
            }
            
            setTimeout(type, 20);
        } else {
            typingText.textContent = currentPhrase.substring(0, charIndex + 1);
            charIndex++;
            
            if (charIndex === currentPhrase.length) {
                isPaused = true;
                setTimeout(type, 100);
                return;
            }
            
            // Variable typing speed for realism
            const speed = Math.random() * 30 + 20;
            setTimeout(type, speed);
        }
    }
    
    // Start typing after a short delay
    setTimeout(type, 1000);
}

// ========================================
// Mobile Menu Toggle
// ========================================

function initMobileMenu() {
    const toggle = document.getElementById('mobile-toggle');
    const navLinks = document.querySelector('.nav-links');
    
    if (!toggle || !navLinks) return;
    
    toggle.addEventListener('click', () => {
        toggle.classList.toggle('active');
        navLinks.classList.toggle('mobile-open');
        
        // Animate hamburger to X
        const spans = toggle.querySelectorAll('span');
        if (toggle.classList.contains('active')) {
            spans[0].style.transform = 'rotate(45deg) translate(5px, 5px)';
            spans[1].style.opacity = '0';
            spans[2].style.transform = 'rotate(-45deg) translate(7px, -6px)';
        } else {
            spans[0].style.transform = '';
            spans[1].style.opacity = '';
            spans[2].style.transform = '';
        }
    });
    
    // Close menu on link click
    navLinks.querySelectorAll('a').forEach(link => {
        link.addEventListener('click', () => {
            toggle.classList.remove('active');
            navLinks.classList.remove('mobile-open');
            toggle.querySelectorAll('span').forEach(span => {
                span.style.transform = '';
                span.style.opacity = '';
            });
        });
    });
}

// ========================================
// Smooth Scroll for Anchor Links
// ========================================

function initSmoothScroll() {
    document.querySelectorAll('a[href^="#"]').forEach(anchor => {
        anchor.addEventListener('click', function(e) {
            e.preventDefault();
            
            const targetId = this.getAttribute('href');
            if (targetId === '#') return;
            
            const target = document.querySelector(targetId);
            if (!target) return;
            
            const navHeight = document.getElementById('nav').offsetHeight;
            const targetPosition = target.getBoundingClientRect().top + window.pageYOffset - navHeight - 20;
            
            window.scrollTo({
                top: targetPosition,
                behavior: 'smooth'
            });
        });
    });
}

// ========================================
// Intersection Observer for Animations
// ========================================

function initScrollAnimations() {
    const observerOptions = {
        root: null,
        rootMargin: '0px',
        threshold: 0.1
    };
    
    const observer = new IntersectionObserver((entries) => {
        entries.forEach(entry => {
            if (entry.isIntersecting) {
                entry.target.classList.add('animate-in');
                observer.unobserve(entry.target);
            }
        });
    }, observerOptions);
    
    // Observe elements with animate class
    document.querySelectorAll('.feature-card, .step, .pricing-card, .faq-item').forEach(el => {
        el.style.opacity = '0';
        el.style.transform = 'translateY(20px)';
        el.style.transition = 'opacity 0.6s ease, transform 0.6s ease';
        observer.observe(el);
    });
}

// Add animate-in styles
const style = document.createElement('style');
style.textContent = `
    .animate-in {
        opacity: 1 !important;
        transform: translateY(0) !important;
    }
`;
document.head.appendChild(style);

// Initialize scroll animations after page load
window.addEventListener('load', initScrollAnimations);

// ========================================
// Waveform Animation Enhancement
// ========================================

function enhanceWaveform() {
    const waveBars = document.querySelectorAll('.wave-bar');
    
    // Add random height variations
    setInterval(() => {
        waveBars.forEach(bar => {
            const randomHeight = Math.random() * 30 + 20;
            bar.style.height = `${randomHeight}px`;
        });
    }, 200);
}

// Only run if page is visible
document.addEventListener('visibilitychange', () => {
    if (document.visibilityState === 'visible') {
        // Resume animations
    } else {
        // Pause heavy animations to save battery
    }
});

// ========================================
// Download Button Analytics (placeholder)
// ========================================

document.querySelectorAll('a[href*="download"], a[href*="apps.apple.com"]').forEach(btn => {
    btn.addEventListener('click', () => {
        // Track download clicks
        if (typeof gtag === 'function') {
            gtag('event', 'download_click', {
                'event_category': 'engagement',
                'event_label': btn.textContent.trim()
            });
        }
    });
});

// ========================================
// Keyboard Shortcut Demo
// ========================================

document.addEventListener('keydown', (e) => {
    // Cmd/Ctrl + Shift + D - Show a fun easter egg
    if ((e.metaKey || e.ctrlKey) && e.shiftKey && e.key === 'd') {
        e.preventDefault();
        
        const notification = document.createElement('div');
        notification.style.cssText = `
            position: fixed;
            bottom: 20px;
            right: 20px;
            padding: 16px 24px;
            background: linear-gradient(135deg, #6366f1 0%, #8b5cf6 100%);
            color: white;
            border-radius: 12px;
            font-weight: 600;
            box-shadow: 0 10px 40px rgba(99, 102, 241, 0.4);
            z-index: 9999;
            animation: slideIn 0.3s ease;
        `;
        notification.textContent = '🎙️ That\'s the shortcut! Download EchoTune to use it.';
        
        document.body.appendChild(notification);
        
        setTimeout(() => {
            notification.style.animation = 'slideOut 0.3s ease forwards';
            setTimeout(() => notification.remove(), 300);
        }, 3000);
    }
});

// Add animation keyframes
const keyframes = document.createElement('style');
keyframes.textContent = `
    @keyframes slideIn {
        from {
            opacity: 0;
            transform: translateX(100px);
        }
        to {
            opacity: 1;
            transform: translateX(0);
        }
    }
    
    @keyframes slideOut {
        from {
            opacity: 1;
            transform: translateX(0);
        }
        to {
            opacity: 0;
            transform: translateX(100px);
        }
    }
    
    /* Mobile menu styles */
    @media (max-width: 768px) {
        .nav-links.mobile-open {
            display: flex !important;
            position: absolute;
            top: 100%;
            left: 0;
            right: 0;
            flex-direction: column;
            padding: 20px;
            background: var(--color-bg);
            border-bottom: 1px solid var(--color-border);
            box-shadow: var(--shadow-lg);
        }
        
        .nav-links.mobile-open a {
            padding: 12px 0;
        }
    }
`;
document.head.appendChild(keyframes);
