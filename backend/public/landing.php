<?php

declare(strict_types=1);

$appName = 'Expense';
$tagline = 'Track spending. Keep more.';
$year = (int) date('Y');

// Replace with your live App Store URL when published.
$appStoreUrl = 'https://apps.apple.com/app/expense/idXXXXXXXXX';

?><!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title><?= htmlspecialchars($appName) ?> — <?= htmlspecialchars($tagline) ?></title>
  <meta name="description" content="Expense is a private, on-device expense tracker for iOS. Quick add, receipt scan, shared trips, budgets, widgets, and Siri — your money stays yours.">
  <meta name="theme-color" content="#0B1B33">
  <meta property="og:title" content="<?= htmlspecialchars($appName) ?>">
  <meta property="og:description" content="<?= htmlspecialchars($tagline) ?>">
  <meta property="og:type" content="website">
  <link rel="preconnect" href="https://fonts.googleapis.com">
  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
  <link href="https://fonts.googleapis.com/css2?family=Outfit:wght@400;500;600;700;800&family=Work+Sans:wght@400;500;600&display=swap" rel="stylesheet">
  <style>
    :root {
      --ink: #0B1B33;
      --ink-soft: #152A47;
      --tide: #3B6EF5;
      --seafoam: #34D399;
      --mist: #E4EAF3;
      --foam: #EEF1F6;
      --foam-deep: #E8EDF6;
      --slate: #3A4A63;
      --muted: #6B7A90;
      --danger: #F0435D;
      --surplus: #12B981;
      --hairline: #D7DEEA;
      --font-display: "Outfit", system-ui, sans-serif;
      --font-body: "Work Sans", system-ui, sans-serif;
      --ease: cubic-bezier(0.22, 1, 0.36, 1);
    }

    *, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }
    html { scroll-behavior: smooth; }
    body {
      font-family: var(--font-body);
      color: var(--ink);
      background: var(--foam);
      line-height: 1.55;
      -webkit-font-smoothing: antialiased;
      overflow-x: hidden;
    }
    a { color: inherit; text-decoration: none; }
    button { font: inherit; cursor: pointer; border: none; background: none; }

    .skip {
      position: absolute; left: -9999px; top: 0;
      background: var(--ink); color: #fff; padding: 0.75rem 1rem; z-index: 100;
    }
    .skip:focus { left: 1rem; top: 1rem; }

    .atmosphere {
      position: fixed; inset: 0; z-index: -1;
      background:
        radial-gradient(ellipse 80% 55% at 12% -8%, rgba(59, 110, 245, 0.18), transparent 55%),
        radial-gradient(ellipse 55% 40% at 92% 8%, rgba(52, 211, 153, 0.14), transparent 50%),
        linear-gradient(180deg, var(--foam) 0%, var(--foam-deep) 50%, #E2E8F2 100%);
    }
    .atmosphere::after {
      content: "";
      position: absolute; inset: 0;
      background-image:
        linear-gradient(rgba(11, 27, 51, 0.03) 1px, transparent 1px),
        linear-gradient(90deg, rgba(11, 27, 51, 0.03) 1px, transparent 1px);
      background-size: 48px 48px;
      mask-image: linear-gradient(180deg, rgba(0,0,0,0.3), transparent 65%);
      pointer-events: none;
    }

    .wrap { width: min(1120px, calc(100% - 2.5rem)); margin-inline: auto; }

    .nav {
      display: flex; align-items: center; justify-content: space-between;
      padding: 1.25rem 0;
      animation: rise 0.7s var(--ease) both;
    }
    .brand {
      display: inline-flex; align-items: center; gap: 0.7rem;
      font-family: var(--font-display); font-weight: 800; font-size: 1.25rem;
      letter-spacing: -0.03em;
    }
    .brand-mark {
      width: 36px; height: 36px; border-radius: 11px;
      background: linear-gradient(145deg, var(--ink), var(--ink-soft));
      display: grid; place-items: center;
      box-shadow: 0 8px 20px rgba(11, 27, 51, 0.22);
    }
    .brand-mark svg { width: 18px; height: 18px; }
    .nav-links { display: flex; align-items: center; gap: 1.35rem; }
    .nav-links a {
      font-size: 0.9rem; font-weight: 500; color: var(--slate);
      transition: color 0.2s ease;
    }
    .nav-links a:hover, .nav-links a:focus-visible { color: var(--tide); }
    .nav-cta {
      display: inline-flex; align-items: center; min-height: 40px;
      padding: 0.45rem 0.95rem; border-radius: 12px;
      background: var(--ink); color: #fff !important;
      font-family: var(--font-display); font-weight: 700; font-size: 0.85rem;
      box-shadow: 0 8px 18px rgba(11, 27, 51, 0.18);
      transition: transform 0.18s ease, background 0.2s ease;
    }
    .nav-cta:hover { transform: translateY(-1px); background: var(--ink-soft); color: #fff !important; }

    .hero {
      min-height: calc(100vh - 5.5rem);
      display: grid; align-items: center;
      padding: 1.5rem 0 4rem; gap: 3rem;
    }
    @media (min-width: 900px) {
      .hero { grid-template-columns: 1.05fr 0.95fr; gap: 3.5rem; padding-top: 2rem; }
    }

    .hero-copy { animation: rise 0.85s var(--ease) 0.08s both; }
    .hero-brand {
      font-family: var(--font-display); font-weight: 800;
      font-size: clamp(3.4rem, 9vw, 5.6rem);
      line-height: 0.95; letter-spacing: -0.055em;
      color: var(--ink); margin-bottom: 1.1rem;
    }
    .hero-headline {
      font-family: var(--font-display); font-weight: 600;
      font-size: clamp(1.35rem, 3.2vw, 1.85rem);
      line-height: 1.25; letter-spacing: -0.03em;
      color: var(--ink-soft); max-width: 16ch; margin-bottom: 0.85rem;
    }
    .hero-support {
      font-size: 1.05rem; color: var(--muted);
      max-width: 36ch; margin-bottom: 1.75rem;
    }
    .cta-row { display: flex; flex-wrap: wrap; gap: 0.75rem; margin-bottom: 1.1rem; }
    .btn {
      display: inline-flex; align-items: center; justify-content: center; gap: 0.55rem;
      min-height: 54px; padding: 0.85rem 1.35rem; border-radius: 14px;
      font-family: var(--font-display); font-weight: 700; font-size: 0.95rem;
      transition: transform 0.18s ease, background 0.2s ease, box-shadow 0.2s ease;
    }
    .btn:hover { transform: translateY(-1px); }
    .btn:focus-visible { outline: 3px solid rgba(59, 110, 245, 0.45); outline-offset: 2px; }
    .btn-primary {
      background: var(--ink); color: #fff;
      box-shadow: 0 12px 28px rgba(11, 27, 51, 0.22);
    }
    .btn-primary:hover { background: var(--ink-soft); }
    .btn-secondary {
      background: rgba(255,255,255,0.8); color: var(--ink);
      border: 1.5px solid var(--hairline);
    }
    .btn-secondary:hover { background: #fff; }
    .apple-icon { width: 18px; height: 18px; }
    .trust-line { font-size: 0.88rem; color: var(--muted); }

    .hero-visual {
      position: relative; display: grid; place-items: center;
      animation: float-in 1s var(--ease) 0.18s both;
    }
    .phone {
      width: min(280px, 78vw); aspect-ratio: 9 / 19.2; border-radius: 36px;
      background: linear-gradient(165deg, #101F38, #0B1B33 55%, #152A47);
      padding: 12px;
      box-shadow: 0 40px 80px rgba(11, 27, 51, 0.28), inset 0 0 0 1px rgba(255,255,255,0.08);
      position: relative; z-index: 2;
      animation: float 7s ease-in-out infinite;
    }
    .phone-screen {
      height: 100%; border-radius: 26px;
      background: linear-gradient(180deg, #F4F7FB, #EEF1F6);
      overflow: hidden; display: flex; flex-direction: column;
      padding: 1.35rem 1rem 1rem; gap: 0.85rem;
    }
    .phone-notch {
      width: 38%; height: 8px; border-radius: 999px;
      background: rgba(11, 27, 51, 0.12); margin: 0 auto 0.4rem;
    }
    .phone-label {
      font-family: var(--font-display); font-size: 0.7rem; font-weight: 700;
      color: var(--muted); letter-spacing: 0.04em; text-transform: uppercase;
    }
    .phone-amount {
      font-family: var(--font-display); font-size: 2rem; font-weight: 800;
      letter-spacing: -0.04em; color: var(--ink); line-height: 1;
    }
    .phone-amount span { font-size: 0.95rem; color: var(--muted); font-weight: 600; margin-left: 0.2rem; }
    .bars {
      display: grid; grid-template-columns: repeat(5, 1fr);
      align-items: end; gap: 0.35rem; height: 72px; margin-top: 0.35rem;
    }
    .bars span {
      display: block; border-radius: 6px 6px 2px 2px;
      background: linear-gradient(180deg, var(--tide), #6B93FF);
      opacity: 0.35; transform-origin: bottom;
      animation: bar-rise 1.1s var(--ease) both;
    }
    .bars span:nth-child(1) { height: 42%; animation-delay: 0.35s; }
    .bars span:nth-child(2) { height: 68%; animation-delay: 0.42s; opacity: 0.55; }
    .bars span:nth-child(3) { height: 88%; animation-delay: 0.5s; opacity: 1; }
    .bars span:nth-child(4) { height: 55%; animation-delay: 0.58s; opacity: 0.65; }
    .bars span:nth-child(5) { height: 34%; animation-delay: 0.66s; }

    .txn {
      display: flex; align-items: center; gap: 0.65rem;
      padding: 0.65rem 0.7rem; background: #fff; border-radius: 14px;
      box-shadow: 0 6px 16px rgba(11, 27, 51, 0.05);
      animation: rise 0.7s var(--ease) both;
    }
    .txn:nth-child(1) { animation-delay: 0.55s; }
    .txn:nth-child(2) { animation-delay: 0.68s; }
    .txn:nth-child(3) { animation-delay: 0.8s; }
    .txn-icon {
      width: 32px; height: 32px; border-radius: 10px;
      display: grid; place-items: center; flex-shrink: 0;
    }
    .txn-icon svg { width: 15px; height: 15px; }
    .txn-meta { flex: 1; min-width: 0; }
    .txn-meta strong {
      display: block; font-family: var(--font-display);
      font-size: 0.78rem; font-weight: 700; color: var(--ink);
    }
    .txn-meta span { font-size: 0.68rem; color: var(--muted); }
    .txn-amt { font-family: var(--font-display); font-size: 0.78rem; font-weight: 700; }
    .txn-amt.out { color: var(--danger); }
    .txn-amt.in { color: var(--surplus); }

    .orb {
      position: absolute; border-radius: 50%; filter: blur(2px);
      z-index: 1; pointer-events: none;
    }
    .orb-a {
      width: 180px; height: 180px; background: rgba(59, 110, 245, 0.22);
      top: 8%; right: 4%; animation: drift 9s ease-in-out infinite;
    }
    .orb-b {
      width: 120px; height: 120px; background: rgba(52, 211, 153, 0.18);
      bottom: 12%; left: 8%; animation: drift 11s ease-in-out infinite reverse;
    }

    section { padding: 4.5rem 0; }
    .section-head { max-width: 36rem; margin-bottom: 2.25rem; }
    .section-head h2 {
      font-family: var(--font-display);
      font-size: clamp(1.7rem, 3.5vw, 2.35rem);
      font-weight: 800; letter-spacing: -0.035em; line-height: 1.15;
      margin-bottom: 0.65rem;
    }
    .section-head p { color: var(--muted); font-size: 1.02rem; }

    .features { display: grid; gap: 1rem; }
    @media (min-width: 700px) { .features { grid-template-columns: repeat(3, 1fr); } }

    .feature {
      padding: 1.4rem 1.3rem 1.5rem; border-radius: 20px;
      background: rgba(255,255,255,0.72);
      border: 1px solid rgba(215, 222, 234, 0.85);
      backdrop-filter: blur(10px);
      transition: transform 0.25s var(--ease), box-shadow 0.25s ease;
      animation: rise 0.7s var(--ease) both;
    }
    .feature:nth-child(1) { animation-delay: 0.05s; }
    .feature:nth-child(2) { animation-delay: 0.12s; }
    .feature:nth-child(3) { animation-delay: 0.19s; }
    .feature:nth-child(4) { animation-delay: 0.26s; }
    .feature:nth-child(5) { animation-delay: 0.33s; }
    .feature:nth-child(6) { animation-delay: 0.4s; }
    .feature:hover {
      transform: translateY(-3px);
      box-shadow: 0 18px 36px rgba(11, 27, 51, 0.08);
    }
    .feature-icon {
      width: 42px; height: 42px; border-radius: 12px;
      background: var(--mist); display: grid; place-items: center;
      margin-bottom: 1rem; color: var(--tide);
    }
    .feature-icon svg { width: 20px; height: 20px; }
    .feature h3 {
      font-family: var(--font-display); font-size: 1.05rem;
      font-weight: 700; letter-spacing: -0.02em; margin-bottom: 0.4rem;
    }
    .feature p { font-size: 0.92rem; color: var(--muted); }

    .how {
      display: grid; gap: 1rem;
    }
    @media (min-width: 800px) { .how { grid-template-columns: repeat(3, 1fr); } }
    .step {
      padding: 1.5rem 1.35rem; border-radius: 20px;
      background: rgba(255,255,255,0.65); border: 1px solid var(--hairline);
    }
    .step-num {
      font-family: var(--font-display); font-weight: 800; font-size: 0.85rem;
      color: var(--tide); letter-spacing: 0.04em; margin-bottom: 0.7rem;
    }
    .step h3 {
      font-family: var(--font-display); font-size: 1.15rem; font-weight: 700;
      letter-spacing: -0.02em; margin-bottom: 0.4rem;
    }
    .step p { color: var(--muted); font-size: 0.95rem; }

    .download {
      padding: 2.25rem; border-radius: 24px; background: var(--ink); color: #fff;
      display: grid; gap: 1.5rem; position: relative; overflow: hidden;
      animation: rise 0.75s var(--ease) both;
    }
    @media (min-width: 800px) {
      .download {
        grid-template-columns: 1.3fr 0.7fr; align-items: center;
        padding: 2.5rem 2.6rem;
      }
    }
    .download::before {
      content: ""; position: absolute; width: 280px; height: 280px;
      border-radius: 50%; background: rgba(59, 110, 245, 0.28);
      top: -80px; right: -60px; pointer-events: none;
    }
    .download h2 {
      font-family: var(--font-display);
      font-size: clamp(1.5rem, 3vw, 2rem);
      font-weight: 800; letter-spacing: -0.03em; margin-bottom: 0.55rem;
      position: relative;
    }
    .download p {
      color: rgba(255,255,255,0.72); font-size: 0.98rem;
      max-width: 40ch; position: relative;
    }
    .download .btn-primary {
      background: #fff; color: var(--ink);
      box-shadow: 0 12px 28px rgba(0,0,0,0.18);
      position: relative;
    }
    .download .btn-primary:hover { background: #F3F6FB; }

    footer {
      padding: 2.5rem 0 3rem;
      border-top: 1px solid rgba(215, 222, 234, 0.9);
      color: var(--muted); font-size: 0.88rem;
    }
    .footer-row {
      display: flex; flex-wrap: wrap; gap: 1rem;
      justify-content: space-between; align-items: center;
    }
    .footer-links { display: flex; gap: 1.25rem; }
    .footer-links a:hover, .footer-links a:focus-visible { color: var(--tide); }

    @keyframes rise {
      from { opacity: 0; transform: translateY(18px); }
      to { opacity: 1; transform: translateY(0); }
    }
    @keyframes float-in {
      from { opacity: 0; transform: translateY(28px) scale(0.96); }
      to { opacity: 1; transform: translateY(0) scale(1); }
    }
    @keyframes float {
      0%, 100% { transform: translateY(0); }
      50% { transform: translateY(-10px); }
    }
    @keyframes drift {
      0%, 100% { transform: translate(0, 0); }
      50% { transform: translate(12px, -16px); }
    }
    @keyframes bar-rise {
      from { transform: scaleY(0); opacity: 0; }
      to { transform: scaleY(1); }
    }

    @media (prefers-reduced-motion: reduce) {
      html { scroll-behavior: auto; }
      *, *::before, *::after { animation: none !important; transition: none !important; }
    }
    @media (max-width: 699px) {
      .nav-links a:not(.nav-cta) { display: none; }
      .hero { min-height: auto; padding-bottom: 3rem; }
    }
  </style>
</head>
<body>
  <a class="skip" href="#main">Skip to content</a>
  <div class="atmosphere" aria-hidden="true"></div>

  <header class="wrap">
    <nav class="nav" aria-label="Primary">
      <a class="brand" href="/">
        <span class="brand-mark" aria-hidden="true">
          <svg viewBox="0 0 24 24" fill="none" stroke="#fff" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round">
            <path d="M12 3v18M7 8h7.5a3.5 3.5 0 0 1 0 7H7"/>
          </svg>
        </span>
        <?= htmlspecialchars($appName) ?>
      </a>
      <div class="nav-links">
        <a href="#features">Features</a>
        <a href="#how">How it works</a>
        <a class="nav-cta" href="<?= htmlspecialchars($appStoreUrl) ?>" rel="noopener">Download</a>
      </div>
    </nav>
  </header>

  <main id="main">
    <section class="hero wrap">
      <div class="hero-copy">
        <p class="hero-brand"><?= htmlspecialchars($appName) ?></p>
        <h1 class="hero-headline"><?= htmlspecialchars($tagline) ?></h1>
        <p class="hero-support">
          A private expense tracker for iPhone — log spending in seconds, scan receipts on-device, split trips with friends, and see where your money goes.
        </p>
        <div class="cta-row">
          <a class="btn btn-primary" href="<?= htmlspecialchars($appStoreUrl) ?>" rel="noopener">
            <svg class="apple-icon" viewBox="0 0 24 24" aria-hidden="true" fill="currentColor">
              <path d="M18.71 12.46c-.03-2.2 1.8-3.26 1.88-3.31-1.03-1.5-2.62-1.7-3.18-1.72-1.35-.14-2.64.8-3.32.8-.69 0-1.75-.78-2.88-.76-1.48.02-2.85.86-3.61 2.18-1.54 2.67-.39 6.62 1.11 8.79.73 1.06 1.61 2.25 2.76 2.21 1.11-.05 1.53-.71 2.87-.71s1.72.71 2.88.69c1.19-.02 1.95-1.08 2.68-2.15.84-1.23 1.18-2.42 1.2-2.48-.03-.01-2.3-.88-2.33-3.54zM15.4 5.18c.6-.73 1.01-1.75.9-2.76-.87.03-1.92.58-2.54 1.31-.56.65-1.05 1.69-.92 2.68 1 .08 2.02-.5 2.56-1.23z"/>
            </svg>
            Download on the App Store
          </a>
          <a class="btn btn-secondary" href="#features">Explore features</a>
        </div>
        <p class="trust-line">Privacy-first · On-device data · Built for iOS 18+</p>
      </div>

      <div class="hero-visual" aria-hidden="true">
        <div class="orb orb-a"></div>
        <div class="orb orb-b"></div>
        <div class="phone">
          <div class="phone-screen">
            <div class="phone-notch"></div>
            <div class="phone-label">Spent this week</div>
            <div class="phone-amount">$428<span>.60</span></div>
            <div class="bars"><span></span><span></span><span></span><span></span><span></span></div>
            <div class="txn">
              <div class="txn-icon" style="background:#FEE2E8;color:var(--danger)">
                <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round"><path d="M4 12h16M12 4v16"/></svg>
              </div>
              <div class="txn-meta"><strong>Groceries</strong><span>Today · Food</span></div>
              <div class="txn-amt out">−$64.20</div>
            </div>
            <div class="txn">
              <div class="txn-icon" style="background:#D1FAE5;color:var(--surplus)">
                <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round"><path d="M12 19V5M5 12l7-7 7 7"/></svg>
              </div>
              <div class="txn-meta"><strong>Payday</strong><span>Mon · Income</span></div>
              <div class="txn-amt in">+$2,400</div>
            </div>
            <div class="txn">
              <div class="txn-icon" style="background:#DBE4FF;color:var(--tide)">
                <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round"><circle cx="12" cy="12" r="8"/><path d="M12 8v4l2.5 2.5"/></svg>
              </div>
              <div class="txn-meta"><strong>Transit pass</strong><span>Sun · Travel</span></div>
              <div class="txn-amt out">−$32.00</div>
            </div>
          </div>
        </div>
      </div>
    </section>

    <section id="features" class="wrap">
      <div class="section-head">
        <h2>Everything you need to stay on top of spending</h2>
        <p>Expense is designed for real life — fast capture, clear insights, and shared trips when friends are involved.</p>
      </div>
      <div class="features">
        <article class="feature">
          <div class="feature-icon">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M12 5v14M5 12h14"/></svg>
          </div>
          <h3>Quick Add</h3>
          <p>Amount-first entry, a floating +, and saved spend shortcuts so logging takes seconds.</p>
        </article>
        <article class="feature">
          <div class="feature-icon">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="3" y="5" width="18" height="14" rx="2"/><circle cx="12" cy="12" r="3"/><path d="M3 9h2M19 9h2"/></svg>
          </div>
          <h3>Receipt scan</h3>
          <p>Photograph a receipt; on-device Vision OCR fills items, prices, and category — nothing leaves your phone.</p>
        </article>
        <article class="feature">
          <div class="feature-icon">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2"/><circle cx="9" cy="7" r="4"/><path d="M23 21v-2a4 4 0 0 0-3-3.87M16 3.13a4 4 0 0 1 0 7.75"/></svg>
          </div>
          <h3>Shared trips</h3>
          <p>Create a trip, share an invite code, split expenses fairly, and see who owes whom.</p>
        </article>
        <article class="feature">
          <div class="feature-icon">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M3 3v18h18"/><path d="M7 14l4-4 3 3 5-6"/></svg>
          </div>
          <h3>Smart insights</h3>
          <p>Category pulse, trends, budgets, and spending insights that help you keep more.</p>
        </article>
        <article class="feature">
          <div class="feature-icon">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="5" y="2" width="14" height="20" rx="3"/><path d="M9 18h6"/></svg>
          </div>
          <h3>Widgets &amp; Siri</h3>
          <p>Home Screen period widgets and voice shortcuts for one-tap or hands-free logging.</p>
        </article>
        <article class="feature">
          <div class="feature-icon">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="3" y="11" width="18" height="10" rx="2"/><path d="M7 11V7a5 5 0 0 1 10 0v4"/></svg>
          </div>
          <h3>Privacy-first</h3>
          <p>Your personal expenses stay on your device. Optional Face ID lock keeps the app yours alone.</p>
        </article>
      </div>
    </section>

    <section id="how" class="wrap">
      <div class="section-head">
        <h2>Simple by design</h2>
        <p>Three steps from download to a clearer picture of your money.</p>
      </div>
      <div class="how">
        <article class="step">
          <div class="step-num">01</div>
          <h3>Download Expense</h3>
          <p>Get the app on iPhone from the App Store and open it — no account required for personal tracking.</p>
        </article>
        <article class="step">
          <div class="step-num">02</div>
          <h3>Log what you spend</h3>
          <p>Use Quick Add, receipt scan, or Siri. Categories, budgets, and widgets keep everything organized.</p>
        </article>
        <article class="step">
          <div class="step-num">03</div>
          <h3>See the pattern</h3>
          <p>Insights and trip balances show where money goes — so you can keep more of it.</p>
        </article>
      </div>
    </section>

    <section id="download" class="wrap">
      <div class="download">
        <div>
          <h2>Ready to track smarter?</h2>
          <p>Download Expense for iPhone and start logging spending the private, fast way.</p>
        </div>
        <div>
          <a class="btn btn-primary" href="<?= htmlspecialchars($appStoreUrl) ?>" rel="noopener">
            <svg class="apple-icon" viewBox="0 0 24 24" aria-hidden="true" fill="currentColor">
              <path d="M18.71 12.46c-.03-2.2 1.8-3.26 1.88-3.31-1.03-1.5-2.62-1.7-3.18-1.72-1.35-.14-2.64.8-3.32.8-.69 0-1.75-.78-2.88-.76-1.48.02-2.85.86-3.61 2.18-1.54 2.67-.39 6.62 1.11 8.79.73 1.06 1.61 2.25 2.76 2.21 1.11-.05 1.53-.71 2.87-.71s1.72.71 2.88.69c1.19-.02 1.95-1.08 2.68-2.15.84-1.23 1.18-2.42 1.2-2.48-.03-.01-2.3-.88-2.33-3.54zM15.4 5.18c.6-.73 1.01-1.75.9-2.76-.87.03-1.92.58-2.54 1.31-.56.65-1.05 1.69-.92 2.68 1 .08 2.02-.5 2.56-1.23z"/>
            </svg>
            Get it on the App Store
          </a>
        </div>
      </div>
    </section>
  </main>

  <footer class="wrap">
    <div class="footer-row">
      <p>© <?= $year ?> <?= htmlspecialchars($appName) ?>. Privacy-first expense tracking for iOS.</p>
      <div class="footer-links">
        <a href="#features">Features</a>
        <a href="#how">How it works</a>
        <a href="<?= htmlspecialchars($appStoreUrl) ?>" rel="noopener">App Store</a>
      </div>
    </div>
  </footer>
</body>
</html>
