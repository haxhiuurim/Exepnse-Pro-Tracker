<?php

declare(strict_types=1);

$appName = 'Expense';
$proName = 'Expense Pro';
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
  <meta name="description" content="Expense for iPhone: Available Today, Quick Add, shared trips, analytics, cloud sync, widgets, and Expense Pro tools — calm money tracking in Obsidian + Jade.">
  <meta name="theme-color" content="#0A0F0E">
  <meta property="og:title" content="<?= htmlspecialchars($appName) ?> — <?= htmlspecialchars($tagline) ?>">
  <meta property="og:description" content="Know what’s left today. Split trips fairly. Sync when you sign in.">
  <meta property="og:type" content="website">
  <link rel="preconnect" href="https://fonts.googleapis.com">
  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
  <link href="https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:wght@400;500;600;700;800&display=swap" rel="stylesheet">
  <style>
    :root {
      --ink: #0A0F0E;
      --ink-soft: #151C1A;
      --ink-mid: #1C2623;
      --tide: #12A87A;
      --tide-soft: #E8F7F1;
      --seafoam: #2ECC8A;
      --canvas: #F7F7F5;
      --canvas-deep: #EFEFED;
      --mist: #EAEAE8;
      --slate: #3A433F;
      --muted: #6B736F;
      --danger: #E85A4F;
      --hairline: #E2E2DE;
      --panel: #FFFFFF;
      --phone-bg: #F4F5F4;
      --font: "Plus Jakarta Sans", ui-rounded, system-ui, sans-serif;
      --ease: cubic-bezier(0.22, 1, 0.36, 1);
      --r-sm: 12px;
      --r-md: 16px;
      --r-lg: 20px;
      --r-xl: 28px;
    }

    *, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }
    html { scroll-behavior: smooth; }
    body {
      font-family: var(--font);
      color: var(--ink);
      background: var(--canvas);
      line-height: 1.55;
      -webkit-font-smoothing: antialiased;
      overflow-x: hidden;
    }
    a { color: inherit; text-decoration: none; }
    img, svg { display: block; }

    .skip {
      position: absolute; left: -9999px; top: 0; z-index: 100;
      background: var(--ink); color: #fff; padding: 0.75rem 1rem;
    }
    .skip:focus { left: 1rem; top: 1rem; }

    .wrap { width: min(1120px, calc(100% - 2.5rem)); margin-inline: auto; }

    /* ——— Full-bleed hero: solid charcoal, no fade wash ——— */
    .hero-plane {
      position: relative;
      min-height: 100svh;
      color: #fff;
      overflow: hidden;
      background: #0A0F0E;
    }
    .hero-plane::before {
      content: "";
      position: absolute;
      inset: 0;
      background: radial-gradient(ellipse 80% 55% at 75% -10%, rgba(255, 255, 255, 0.03), transparent 50%);
      pointer-events: none;
    }

    .nav {
      display: flex; align-items: center; justify-content: space-between;
      padding: 1.2rem 0 0;
      position: relative; z-index: 2;
      animation: rise 0.7s var(--ease) both;
    }
    .brand {
      display: inline-flex; align-items: center; gap: 0.7rem;
      font-weight: 800; font-size: 1.15rem; letter-spacing: -0.03em;
      color: #fff;
    }
    .brand-mark {
      width: 36px; height: 36px; border-radius: 11px;
      background: rgba(255,255,255,0.1);
      display: grid; place-items: center;
      border: 1px solid rgba(255,255,255,0.12);
    }
    .brand-mark svg { width: 16px; height: 16px; }
    .nav-links { display: flex; align-items: center; gap: 1.35rem; }
    .nav-links a {
      font-size: 0.86rem; font-weight: 600; color: rgba(255,255,255,0.72);
      transition: color 0.2s ease;
    }
    .nav-links a:hover, .nav-links a:focus-visible { color: #fff; }
    .nav-cta {
      min-height: 40px; padding: 0.4rem 1rem; border-radius: 14px;
      background: #fff; color: var(--ink) !important; font-weight: 700; font-size: 0.82rem;
      transition: transform 0.18s ease, background 0.2s ease;
    }
    .nav-cta:hover { transform: translateY(-1px); background: #F0F0EE; }

    .hero-grid {
      position: relative; z-index: 1;
      display: grid; align-items: end;
      gap: 2.5rem;
      padding: 3.5rem 0 5.5rem;
      min-height: calc(100svh - 5.5rem);
    }
    @media (min-width: 960px) {
      .hero-grid {
        grid-template-columns: 1.05fr 0.95fr;
        align-items: center;
        gap: 3rem;
        padding: 2.5rem 0 6rem;
      }
    }

    .hero-copy { animation: rise 0.85s var(--ease) 0.08s both; max-width: 34rem; }
    .hero-brand {
      font-weight: 800;
      font-size: clamp(3.6rem, 10vw, 6rem);
      line-height: 0.9; letter-spacing: -0.06em;
      margin-bottom: 1.1rem;
    }
    .hero-headline {
      font-weight: 700;
      font-size: clamp(1.35rem, 3vw, 1.75rem);
      line-height: 1.2; letter-spacing: -0.03em;
      color: rgba(255,255,255,0.92);
      margin-bottom: 0.75rem;
    }
    .hero-support {
      font-size: 1.05rem; color: rgba(255,255,255,0.62);
      max-width: 36ch; margin-bottom: 1.75rem;
    }
    .cta-row { display: flex; flex-wrap: wrap; gap: 0.75rem; }
    .btn {
      display: inline-flex; align-items: center; justify-content: center; gap: 0.5rem;
      min-height: 52px; padding: 0.8rem 1.3rem; border-radius: var(--r-md);
      font-weight: 700; font-size: 0.92rem;
      transition: transform 0.18s ease, background 0.2s ease, box-shadow 0.2s ease;
    }
    .btn:hover { transform: translateY(-1px); }
    .btn:focus-visible { outline: 3px solid rgba(124, 255, 196, 0.45); outline-offset: 3px; }
    .btn-light {
      background: #fff; color: var(--ink);
      box-shadow: 0 14px 32px rgba(0,0,0,0.18);
    }
    .btn-light:hover { background: #F0F0EE; }
    .btn-ghost {
      background: rgba(255,255,255,0.08); color: #fff;
      border: 1px solid rgba(255,255,255,0.14);
    }
    .btn-ghost:hover { background: rgba(255,255,255,0.14); }
    .btn-dark {
      background: var(--ink); color: #fff;
      box-shadow: 0 12px 28px rgba(10, 15, 14, 0.16);
    }
    .btn-dark:hover { background: var(--ink-soft); }
    .btn-outline {
      background: var(--panel); color: var(--ink);
      border: 1.5px solid var(--hairline);
    }
    .apple-icon { width: 17px; height: 17px; }

    .hero-visual {
      position: relative;
      animation: float-in 1s var(--ease) 0.16s both;
      display: flex; justify-content: center;
    }

    .phone {
      width: min(292px, 78vw);
      border-radius: 38px;
      background: linear-gradient(165deg, #1A2220, #0A0F0E);
      padding: 10px;
      box-shadow:
        0 0 0 1px rgba(255,255,255,0.06),
        0 36px 70px rgba(0, 0, 0, 0.5);
      animation: float 7.5s ease-in-out infinite;
    }
    .phone-screen {
      border-radius: 30px;
      background: var(--phone-bg);
      overflow: hidden;
      padding: 1.05rem 0.9rem 0.95rem;
      display: flex; flex-direction: column; gap: 0.65rem;
      color: var(--ink);
    }
    .phone-notch {
      width: 34%; height: 6px; border-radius: 999px;
      background: rgba(10, 15, 14, 0.12); margin: 0 auto 0.1rem;
    }
    .spent-hero {
      border-radius: 22px; padding: 1rem 0.95rem 0.9rem;
      background:
        radial-gradient(circle at 100% 0%, rgba(18, 168, 122, 0.18), transparent 50%),
        linear-gradient(145deg, #0A0F0E, #151C1A 55%, #1C2623);
      color: #fff;
    }
    .spent-label {
      font-size: 0.58rem; font-weight: 700; letter-spacing: 0.12em;
      color: rgba(255,255,255,0.5); margin-bottom: 0.4rem;
      text-transform: uppercase;
    }
    .spent-amount {
      font-size: 1.8rem; font-weight: 800; letter-spacing: -0.04em;
      line-height: 1; margin-bottom: 0.75rem;
    }
    .spent-pills { display: flex; gap: 0.35rem; }
    .spent-pills span {
      flex: 1; text-align: center; font-size: 0.58rem; font-weight: 700;
      padding: 0.38rem 0; border-radius: 9px;
      color: rgba(255,255,255,0.5); background: rgba(255,255,255,0.06);
    }
    .spent-pills span.on { color: var(--ink); background: #fff; }
    .tile-row { display: grid; grid-template-columns: 1fr 1fr; gap: 0.5rem; }
    .tile {
      background: var(--panel); border-radius: 14px; padding: 0.65rem 0.7rem;
      box-shadow: 0 1px 0 rgba(10, 15, 14, 0.04), 0 6px 16px rgba(10, 15, 14, 0.04);
      border: 1px solid var(--hairline);
    }
    .tile span {
      display: block; font-size: 0.56rem; font-weight: 700;
      letter-spacing: 0.07em; color: var(--muted); margin-bottom: 0.15rem;
      text-transform: uppercase;
    }
    .tile strong { font-size: 0.92rem; font-weight: 800; letter-spacing: -0.02em; }
    .tile .jade { color: var(--tide); }
    .txn {
      display: flex; align-items: center; gap: 0.55rem;
      padding: 0.55rem 0.6rem; background: var(--panel); border-radius: 12px;
      box-shadow: 0 1px 0 rgba(10, 15, 14, 0.04);
      border: 1px solid var(--hairline);
    }
    .txn-ico {
      width: 28px; height: 28px; border-radius: 9px;
      display: grid; place-items: center; flex-shrink: 0;
    }
    .txn-ico svg { width: 13px; height: 13px; }
    .txn-meta { flex: 1; min-width: 0; }
    .txn-meta strong { display: block; font-size: 0.72rem; font-weight: 700; }
    .txn-meta span { font-size: 0.6rem; color: var(--muted); }
    .txn-amt { font-size: 0.72rem; font-weight: 700; color: var(--danger); }

    /* ——— Page sections ——— */
    .page-bg {
      background:
        radial-gradient(ellipse 80% 50% at 50% -10%, rgba(10, 15, 14, 0.03), transparent 55%),
        var(--canvas);
    }

    section.block { padding: 4.5rem 0; }
    .eyebrow {
      font-size: 0.7rem; font-weight: 800; letter-spacing: 0.12em;
      color: var(--tide); text-transform: uppercase; margin-bottom: 0.55rem;
    }
    .block-head { max-width: 36rem; margin-bottom: 2.1rem; }
    .block-head h2 {
      font-size: clamp(1.7rem, 3.5vw, 2.35rem);
      font-weight: 800; letter-spacing: -0.04em; line-height: 1.12;
      margin-bottom: 0.55rem;
    }
    .block-head p { color: var(--muted); font-size: 1.02rem; }

    /* Feature showcase — one job per band */
    .showcase {
      display: grid; gap: 1rem;
    }
    @media (min-width: 800px) {
      .showcase { grid-template-columns: 1.1fr 0.9fr; align-items: stretch; }
      .showcase.reverse { direction: rtl; }
      .showcase.reverse > * { direction: ltr; }
    }
    .showcase-copy {
      padding: 1.75rem 1.6rem;
      border-radius: var(--r-xl);
      background:
        radial-gradient(ellipse 60% 50% at 100% 0%, rgba(18, 168, 122, 0.12), transparent 55%),
        linear-gradient(150deg, #0A0F0E, #151C1A 60%, #1C2623);
      color: #fff;
      display: flex; flex-direction: column; justify-content: center;
      min-height: 280px;
      animation: rise 0.7s var(--ease) both;
      border: 1px solid rgba(255,255,255,0.06);
    }
    .showcase-copy h3 {
      font-size: clamp(1.4rem, 2.5vw, 1.75rem);
      font-weight: 800; letter-spacing: -0.03em;
      margin: 0.4rem 0 0.65rem;
    }
    .showcase-copy p { color: rgba(255,255,255,0.68); font-size: 0.98rem; max-width: 34ch; }
    .showcase-panel {
      padding: 1.5rem;
      border-radius: var(--r-xl);
      background: var(--panel);
      border: 1px solid var(--hairline);
      box-shadow: 0 12px 32px rgba(10, 15, 14, 0.04);
      display: flex; flex-direction: column; gap: 0.85rem;
      justify-content: center;
    }
    .mini-row {
      display: flex; align-items: center; justify-content: space-between;
      padding: 0.85rem 1rem; border-radius: var(--r-md);
      background: var(--canvas);
      border: 1px solid var(--hairline);
    }
    .mini-row strong { font-size: 0.92rem; font-weight: 700; }
    .mini-row span { font-size: 0.78rem; color: var(--muted); }
    .jade-text { color: var(--tide); font-weight: 800; }
    .bar {
      height: 8px; border-radius: 999px; background: var(--mist);
      overflow: hidden;
    }
    .bar > i {
      display: block; height: 100%; border-radius: 999px;
      background: linear-gradient(90deg, var(--tide), #3BC98F);
      width: 68%;
    }

    /* Feature grid — comprehensive */
    .feature-grid {
      display: grid; gap: 0.75rem;
      grid-template-columns: 1fr;
    }
    @media (min-width: 640px) { .feature-grid { grid-template-columns: 1fr 1fr; } }
    @media (min-width: 960px) { .feature-grid { grid-template-columns: repeat(3, 1fr); } }

    .feature {
      padding: 1.2rem 1.15rem 1.25rem;
      border-radius: var(--r-lg);
      background: var(--panel);
      border: 1px solid var(--hairline);
      box-shadow: 0 8px 24px rgba(10, 15, 14, 0.03);
      transition: transform 0.22s var(--ease), border-color 0.22s ease;
      animation: rise 0.65s var(--ease) both;
    }
    .feature:hover { transform: translateY(-2px); border-color: #D4D4D0; }
    .feature:nth-child(1) { animation-delay: 0.02s; }
    .feature:nth-child(2) { animation-delay: 0.06s; }
    .feature:nth-child(3) { animation-delay: 0.1s; }
    .feature:nth-child(4) { animation-delay: 0.14s; }
    .feature:nth-child(5) { animation-delay: 0.18s; }
    .feature:nth-child(6) { animation-delay: 0.22s; }
    .feature:nth-child(7) { animation-delay: 0.26s; }
    .feature:nth-child(8) { animation-delay: 0.3s; }
    .feature:nth-child(9) { animation-delay: 0.34s; }
    .feature:nth-child(10) { animation-delay: 0.38s; }
    .feature:nth-child(11) { animation-delay: 0.42s; }
    .feature:nth-child(12) { animation-delay: 0.46s; }
    .f-ico {
      width: 40px; height: 40px; border-radius: 12px;
      background: var(--tide-soft); color: var(--tide);
      display: grid; place-items: center; margin-bottom: 0.85rem;
    }
    .f-ico svg { width: 18px; height: 18px; }
    .feature h3 {
      font-size: 0.98rem; font-weight: 700;
      letter-spacing: -0.02em; margin-bottom: 0.3rem;
    }
    .feature p { font-size: 0.88rem; color: var(--muted); }

    /* Pro band */
    .pro-band {
      border-radius: var(--r-xl);
      padding: 2rem 1.6rem;
      background:
        radial-gradient(ellipse 50% 40% at 90% 0%, rgba(18, 168, 122, 0.16), transparent 50%),
        linear-gradient(150deg, #070B0A, #0A0F0E 45%, #151C1A);
      color: #fff;
      box-shadow: 0 22px 44px rgba(10, 15, 14, 0.18);
      border: 1px solid rgba(255,255,255,0.06);
    }
    @media (min-width: 900px) {
      .pro-band { padding: 2.5rem 2.4rem; }
    }
    .pro-band .eyebrow { color: var(--seafoam); }
    .pro-band h2 {
      font-size: clamp(1.55rem, 3vw, 2.1rem);
      font-weight: 800; letter-spacing: -0.035em;
      margin: 0.35rem 0 0.55rem;
    }
    .pro-band > p {
      color: rgba(255,255,255,0.68); max-width: 42ch;
      margin-bottom: 1.5rem; font-size: 1rem;
    }
    .pro-list {
      display: grid; gap: 0.55rem;
    }
    @media (min-width: 700px) {
      .pro-list { grid-template-columns: 1fr 1fr; }
    }
    .pro-item {
      display: flex; gap: 0.75rem; align-items: flex-start;
      padding: 0.85rem 0.95rem;
      border-radius: var(--r-md);
      background: rgba(255,255,255,0.06);
      border: 1px solid rgba(255,255,255,0.08);
    }
    .pro-item svg {
      width: 18px; height: 18px; flex-shrink: 0; margin-top: 0.1rem;
      color: var(--seafoam);
    }
    .pro-item strong {
      display: block; font-size: 0.9rem; font-weight: 700;
      margin-bottom: 0.15rem;
    }
    .pro-item span { font-size: 0.82rem; color: rgba(255,255,255,0.58); }

    /* How */
    .how { display: grid; gap: 0.75rem; }
    @media (min-width: 800px) { .how { grid-template-columns: repeat(3, 1fr); } }
    .step {
      padding: 1.4rem 1.25rem;
      border-radius: var(--r-lg);
      background: var(--panel);
      border: 1px solid var(--hairline);
      box-shadow: 0 8px 24px rgba(10, 15, 14, 0.03);
    }
    .step-num {
      font-size: 0.7rem; font-weight: 800; letter-spacing: 0.1em;
      color: var(--tide); margin-bottom: 0.65rem;
    }
    .step h3 {
      font-size: 1.05rem; font-weight: 700;
      letter-spacing: -0.02em; margin-bottom: 0.35rem;
    }
    .step p { color: var(--muted); font-size: 0.92rem; }

    /* Final CTA */
    .final-cta {
      text-align: center;
      padding: 3.5rem 1.5rem;
      border-radius: var(--r-xl);
      background: var(--panel);
      border: 1px solid var(--hairline);
      box-shadow: 0 12px 32px rgba(10, 15, 14, 0.04);
    }
    .final-cta h2 {
      font-size: clamp(1.6rem, 3vw, 2.2rem);
      font-weight: 800; letter-spacing: -0.04em;
      margin-bottom: 0.55rem;
    }
    .final-cta p {
      color: var(--muted); max-width: 36ch; margin: 0 auto 1.5rem;
    }
    .final-cta .cta-row { justify-content: center; }

    footer {
      padding: 2.5rem 0 3rem;
      border-top: 1px solid var(--hairline);
      color: var(--muted); font-size: 0.86rem;
    }
    .footer-row {
      display: flex; flex-wrap: wrap; gap: 1rem;
      justify-content: space-between; align-items: center;
    }
    .footer-links { display: flex; flex-wrap: wrap; gap: 1.15rem; }
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

    @media (prefers-reduced-motion: reduce) {
      html { scroll-behavior: auto; }
      *, *::before, *::after { animation: none !important; transition: none !important; }
    }
    @media (max-width: 799px) {
      .nav-links a:not(.nav-cta) { display: none; }
      .hero-grid { min-height: auto; padding-top: 2.5rem; padding-bottom: 4.5rem; }
    }
  </style>
</head>
<body>
  <a class="skip" href="#main">Skip to content</a>

  <header class="hero-plane">
    <div class="wrap">
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
          <a href="#trips">Trips</a>
          <a href="#pro">Pro</a>
          <a class="nav-cta" href="<?= htmlspecialchars($appStoreUrl) ?>" rel="noopener">Download</a>
        </div>
      </nav>

      <div class="hero-grid">
        <div class="hero-copy">
          <p class="hero-brand"><?= htmlspecialchars($appName) ?></p>
          <h1 class="hero-headline"><?= htmlspecialchars($tagline) ?></h1>
          <p class="hero-support">
            Know what’s left today. Log in seconds. Split trips fairly — calm money tracking for iPhone.
          </p>
          <div class="cta-row">
            <a class="btn btn-light" href="<?= htmlspecialchars($appStoreUrl) ?>" rel="noopener">
              <svg class="apple-icon" viewBox="0 0 24 24" aria-hidden="true" fill="currentColor">
                <path d="M18.71 12.46c-.03-2.2 1.8-3.26 1.88-3.31-1.03-1.5-2.62-1.7-3.18-1.72-1.35-.14-2.64.8-3.32.8-.69 0-1.75-.78-2.88-.76-1.48.02-2.85.86-3.61 2.18-1.54 2.67-.39 6.62 1.11 8.79.73 1.06 1.61 2.25 2.76 2.21 1.11-.05 1.53-.71 2.87-.71s1.72.71 2.88.69c1.19-.02 1.95-1.08 2.68-2.15.84-1.23 1.18-2.42 1.2-2.48-.03-.01-2.3-.88-2.33-3.54zM15.4 5.18c.6-.73 1.01-1.75.9-2.76-.87.03-1.92.58-2.54 1.31-.56.65-1.05 1.69-.92 2.68 1 .08 2.02-.5 2.56-1.23z"/>
              </svg>
              Download on the App Store
            </a>
            <a class="btn btn-ghost" href="#features">Explore features</a>
          </div>
        </div>

        <div class="hero-visual" aria-hidden="true">
          <div class="phone">
            <div class="phone-screen">
              <div class="phone-notch"></div>
              <div class="spent-hero">
                <div class="spent-label">Spent this week</div>
                <div class="spent-amount">€428.60</div>
                <div class="spent-pills">
                  <span>Day</span><span class="on">Week</span><span>Month</span><span>Year</span>
                </div>
              </div>
              <div class="tile-row">
                <div class="tile"><span>Available today</span><strong class="jade">€86</strong></div>
                <div class="tile"><span>Cash</span><strong>€1,240</strong></div>
              </div>
              <div class="txn">
                <div class="txn-ico" style="background:#FDE8E6;color:var(--danger)">
                  <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round"><path d="M4 12h16"/></svg>
                </div>
                <div class="txn-meta"><strong>Groceries</strong><span>Today · Food</span></div>
                <div class="txn-amt">−€64.20</div>
              </div>
              <div class="txn">
                <div class="txn-ico" style="background:var(--tide-soft);color:var(--tide)">
                  <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2"><path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2"/><circle cx="9" cy="7" r="4"/></svg>
                </div>
                <div class="txn-meta"><strong>Lisbon trip</strong><span>Shared · 4 people</span></div>
                <div class="txn-amt">−€48.00</div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  </header>

  <main id="main" class="page-bg">
    <!-- Available Today showcase -->
    <section class="block wrap" id="available">
      <div class="showcase">
        <div class="showcase-copy">
          <p class="eyebrow" style="color:var(--seafoam)">Home</p>
          <h3>Available Today</h3>
          <p>Income, bills, savings, and cash on hand become one daily number — so you know what you can spend before you buy.</p>
        </div>
        <div class="showcase-panel">
          <div class="mini-row">
            <div><strong>Today’s budget</strong><br><span>Capped by liquid cash</span></div>
            <div class="jade-text">€86</div>
          </div>
          <div>
            <div class="mini-row" style="margin-bottom:0.5rem;background:transparent;padding:0">
              <span>Month progress</span><span>68%</span>
            </div>
            <div class="bar"><i></i></div>
          </div>
          <div class="mini-row">
            <div><strong>Cash on hand</strong><br><span>Wallet + checking</span></div>
            <div><strong>€1,240</strong></div>
          </div>
        </div>
      </div>
    </section>

    <!-- Comprehensive features -->
    <section class="block wrap" id="features">
      <div class="block-head">
        <p class="eyebrow">Everything in the app</p>
        <h2>Built for how you actually spend</h2>
        <p>From Quick Add to shared trips and Pro exports — the same Obsidian + Jade experience on every screen.</p>
      </div>
      <div class="feature-grid">
        <article class="feature">
          <div class="f-ico"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"><path d="M12 5v14M5 12h14"/></svg></div>
          <h3>Quick Add</h3>
          <p>Amount-first entry and natural language like “Coffee 4.50” so logging takes seconds.</p>
        </article>
        <article class="feature">
          <div class="f-ico"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"><path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"/><path d="M14 2v6h6M16 13H8M16 17H8M10 9H8"/></svg></div>
          <h3>Income &amp; expenses</h3>
          <p>Track both directions with categories, search, sort, and a clean activity timeline.</p>
        </article>
        <article class="feature">
          <div class="f-ico"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"><path d="M3 3v18h18"/><path d="M7 14l4-4 3 3 5-6"/></svg></div>
          <h3>Insights &amp; analytics</h3>
          <p>Category pulse, trends, budgets, heatmaps, and pace projections that show where money goes.</p>
        </article>
        <article class="feature">
          <div class="f-ico"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"><circle cx="12" cy="12" r="9"/><path d="M12 7v5l3 2"/></svg></div>
          <h3>Budgets</h3>
          <p>Overall and per-category limits with progress and alerts when you’re running hot.</p>
        </article>
        <article class="feature">
          <div class="f-ico"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"><path d="M12 3v3M12 18v3M3 12h3M18 12h3"/><circle cx="12" cy="12" r="4"/></svg></div>
          <h3>Cloud account sync</h3>
          <p>Sign in to back up your ledger to Expense servers. Guest mode stays on this device only.</p>
        </article>
        <article class="feature">
          <div class="f-ico"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"><rect x="5" y="2" width="14" height="20" rx="3"/><path d="M9 18h6"/></svg></div>
          <h3>Home Screen widgets</h3>
          <p>Spend summaries and trip widgets with one-tap add — glanceable without opening the app.</p>
        </article>
        <article class="feature">
          <div class="f-ico"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"><path d="M12 2a5 5 0 0 1 5 5v3H7V7a5 5 0 0 1 5-5z"/><rect x="5" y="10" width="14" height="11" rx="2"/></svg></div>
          <h3>Biometric lock</h3>
          <p>Face ID / Touch ID to keep your ledger private when you leave the app.</p>
        </article>
        <article class="feature">
          <div class="f-ico"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"><circle cx="12" cy="12" r="9"/><path d="M3 12h18M12 3a15 15 0 0 1 0 18M12 3a15 15 0 0 0 0 18"/></svg></div>
          <h3>Multi-currency</h3>
          <p>Pick your home currency in onboarding and keep amounts consistent across trips.</p>
        </article>
        <article class="feature">
          <div class="f-ico"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"><path d="M23 19a2 2 0 0 1-2 2H3a2 2 0 0 1-2-2V8a2 2 0 0 1 2-2h4l2-3h6l2 3h4a2 2 0 0 1 2 2z"/><circle cx="12" cy="13" r="4"/></svg></div>
          <h3>Receipt scan</h3>
          <p>Point the camera, capture the total, and file it — OCR depth unlocks further with Pro.</p>
        </article>
        <article class="feature">
          <div class="f-ico"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"><path d="M20.59 13.41l-7.17 7.17a2 2 0 0 1-2.83 0L2 12V2h10l8.59 8.59a2 2 0 0 1 0 2.82z"/><line x1="7" y1="7" x2="7.01" y2="7"/></svg></div>
          <h3>Tags &amp; categories</h3>
          <p>Organize with built-in categories; Pro adds custom categories, unlimited tags, and merchant rules.</p>
        </article>
        <article class="feature">
          <div class="f-ico"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"><rect x="3" y="4" width="18" height="18" rx="2"/><path d="M16 2v4M8 2v4M3 10h18"/></svg></div>
          <h3>Subscriptions</h3>
          <p>Track recurring charges and burn alerts so memberships don’t sneak past you.</p>
        </article>
        <article class="feature">
          <div class="f-ico"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"><path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z"/></svg></div>
          <h3>Private by default</h3>
          <p>Your personal ledger lives on device until you sign in. Trips use your Expense account securely.</p>
        </article>
      </div>
    </section>

    <!-- Trips deep dive -->
    <section class="block wrap" id="trips">
      <div class="block-head">
        <p class="eyebrow">Shared trips</p>
        <h2>Split fairly. Settle cleanly.</h2>
        <p>Group expenses without bank linking — invite codes, approvals, and balances that make sense.</p>
      </div>
      <div class="showcase reverse">
        <div class="showcase-copy">
          <p class="eyebrow" style="color:var(--seafoam)">Trips</p>
          <h3>Everyone’s share, clearly</h3>
          <p>Choose who paid, split with everyone or selected people, add guests without the app, and settle debts when the trip is done.</p>
        </div>
        <div class="showcase-panel">
          <div class="mini-row">
            <div><strong>Weekend in Lisbon</strong><br><span>4 people · invite code</span></div>
            <div class="jade-text">€812</div>
          </div>
          <div class="mini-row">
            <div><strong>You are owed</strong><br><span>After dinner + taxi</span></div>
            <div class="jade-text">+€64</div>
          </div>
          <div class="mini-row">
            <div><strong>Category spend</strong><br><span>Food · Stay · Transit</span></div>
            <div><strong>Chart in trip</strong></div>
          </div>
        </div>
      </div>
      <div class="feature-grid" style="margin-top:1rem">
        <article class="feature">
          <div class="f-ico"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"><path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2"/><circle cx="9" cy="7" r="4"/><path d="M23 21v-2a4 4 0 0 0-3-3.87M16 3.13a4 4 0 0 1 0 7.75"/></svg></div>
          <h3>Invite &amp; approve</h3>
          <p>Share a code. Friends request to join — you approve before they see the trip.</p>
        </article>
        <article class="feature">
          <div class="f-ico"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"><path d="M12 1v22M17 5H9.5a3.5 3.5 0 0 0 0 7h5a3.5 3.5 0 0 1 0 7H6"/></svg></div>
          <h3>Flexible splits</h3>
          <p>Pick the payer, split with all or a few, and track who added each expense.</p>
        </article>
        <article class="feature">
          <div class="f-ico"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"><path d="M16 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2"/><circle cx="8.5" cy="7" r="4"/><line x1="20" y1="8" x2="20" y2="14"/><line x1="23" y1="11" x2="17" y2="11"/></svg></div>
          <h3>Manual members</h3>
          <p>Add people by name when they don’t have the app — still saved on the trip.</p>
        </article>
        <article class="feature">
          <div class="f-ico"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"><path d="M22 11.08V12a10 10 0 1 1-5.93-9.14"/><polyline points="22 4 12 14.01 9 11.01"/></svg></div>
          <h3>Settle debts</h3>
          <p>Owner confirms who owes whom, then resets balances while keeping the trip total.</p>
        </article>
        <article class="feature">
          <div class="f-ico"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"><path d="M21.21 15.89A10 10 0 1 1 8 2.83"/><path d="M22 12A10 10 0 0 0 12 2v10z"/></svg></div>
          <h3>Trip analytics</h3>
          <p>See spend by category inside each trip — food, stay, transit, and more.</p>
        </article>
        <article class="feature">
          <div class="f-ico"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"><path d="M3 9l9-7 9 7v11a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z"/></svg></div>
          <h3>Home shortcuts</h3>
          <p>Pin trips to Home for fast add expense — and trip widgets on your Home Screen.</p>
        </article>
      </div>
    </section>

    <!-- Pro -->
    <section class="block wrap" id="pro">
      <div class="pro-band">
        <p class="eyebrow"><?= htmlspecialchars($proName) ?></p>
        <h2>Go deeper when you’re ready</h2>
        <p>Unlock forecasts, unlimited tools, exports, and Live Activities — without changing the calm look of Expense.</p>
        <div class="pro-list">
          <div class="pro-item">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="12" cy="12" r="5"/><path d="M12 1v2M12 21v2M4.2 4.2l1.4 1.4M18.4 18.4l1.4 1.4M1 12h2M21 12h2M4.2 19.8l1.4-1.4M18.4 5.6l1.4-1.4"/></svg>
            <div><strong>Available Today depth</strong><span>Forecasts, alerts, and unlimited budgets</span></div>
          </div>
          <div class="pro-item">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"/><path d="M14 2v6h6"/></svg>
            <div><strong>Receipt scans</strong><span>OCR without a monthly cap</span></div>
          </div>
          <div class="pro-item">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M3 3v18h18"/><path d="M7 14l4-4 3 3 5-6"/></svg>
            <div><strong>Full Insights</strong><span>Trends, patterns, heatmap, projections</span></div>
          </div>
          <div class="pro-item">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><rect x="1" y="4" width="22" height="16" rx="2"/><path d="M1 10h22"/></svg>
            <div><strong>Subscriptions</strong><span>Unlimited recurring &amp; burn alerts</span></div>
          </div>
          <div class="pro-item">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M20.59 13.41l-7.17 7.17a2 2 0 0 1-2.83 0L2 12V2h10l8.59 8.59a2 2 0 0 1 0 2.82z"/></svg>
            <div><strong>Tags &amp; custom categories</strong><span>Unlimited tags and your own category set</span></div>
          </div>
          <div class="pro-item">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"/><polyline points="7 10 12 15 17 10"/><line x1="12" y1="15" x2="12" y2="3"/></svg>
            <div><strong>CSV / OFX / PDF export</strong><span>Taxes, accountants, and records</span></div>
          </div>
          <div class="pro-item">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="12" cy="12" r="10"/><circle cx="12" cy="12" r="6"/><circle cx="12" cy="12" r="2"/></svg>
            <div><strong>Savings goals</strong><span>Targets and envelopes you can track</span></div>
          </div>
          <div class="pro-item">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><rect x="1" y="4" width="22" height="16" rx="2"/><path d="M1 10h22"/></svg>
            <div><strong>Debt &amp; EMI</strong><span>Payoff plans without bank sync</span></div>
          </div>
          <div class="pro-item">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M13 2L3 14h9l-1 8 10-12h-9l1-8z"/></svg>
            <div><strong>Merchant rules</strong><span>Auto-categorize by payee name</span></div>
          </div>
          <div class="pro-item">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><rect x="5" y="2" width="14" height="20" rx="2"/><path d="M12 18h.01"/></svg>
            <div><strong>Live Activities</strong><span>Spent Today on the Lock Screen</span></div>
          </div>
        </div>
      </div>
    </section>

    <!-- How -->
    <section class="block wrap" id="how">
      <div class="block-head">
        <p class="eyebrow">How it works</p>
        <h2>Three steps to clearer money</h2>
        <p>From download to Available Today — without a learning curve.</p>
      </div>
      <div class="how">
        <article class="step">
          <div class="step-num">01</div>
          <h3>Download Expense</h3>
          <p>Open on iPhone, set currency and cash, then sign in for sync — or continue as a guest.</p>
        </article>
        <article class="step">
          <div class="step-num">02</div>
          <h3>Log what you spend</h3>
          <p>Quick Add, receipts, or trip expenses. Categories, budgets, and trips stay organized.</p>
        </article>
        <article class="step">
          <div class="step-num">03</div>
          <h3>See what’s left</h3>
          <p>Available Today, insights, and trip balances help you keep more of what you earn.</p>
        </article>
      </div>
    </section>

    <section class="block wrap" id="download">
      <div class="final-cta">
        <h2>Ready when you are</h2>
        <p>Get Expense for iPhone — the same calm banking home, widgets, and trips you just saw.</p>
        <div class="cta-row">
          <a class="btn btn-dark" href="<?= htmlspecialchars($appStoreUrl) ?>" rel="noopener">
            <svg class="apple-icon" viewBox="0 0 24 24" aria-hidden="true" fill="currentColor">
              <path d="M18.71 12.46c-.03-2.2 1.8-3.26 1.88-3.31-1.03-1.5-2.62-1.7-3.18-1.72-1.35-.14-2.64.8-3.32.8-.69 0-1.75-.78-2.88-.76-1.48.02-2.85.86-3.61 2.18-1.54 2.67-.39 6.62 1.11 8.79.73 1.06 1.61 2.25 2.76 2.21 1.11-.05 1.53-.71 2.87-.71s1.72.71 2.88.69c1.19-.02 1.95-1.08 2.68-2.15.84-1.23 1.18-2.42 1.2-2.48-.03-.01-2.3-.88-2.33-3.54zM15.4 5.18c.6-.73 1.01-1.75.9-2.76-.87.03-1.92.58-2.54 1.31-.56.65-1.05 1.69-.92 2.68 1 .08 2.02-.5 2.56-1.23z"/>
            </svg>
            Get it on the App Store
          </a>
          <a class="btn btn-outline" href="#pro">See Pro features</a>
        </div>
      </div>
    </section>
  </main>

  <footer class="wrap">
    <div class="footer-row">
      <p>© <?= $year ?> <?= htmlspecialchars($appName) ?>. Calm expense tracking for iOS.</p>
      <div class="footer-links">
        <a href="#features">Features</a>
        <a href="#trips">Trips</a>
        <a href="#pro">Pro</a>
        <a href="<?= htmlspecialchars($appStoreUrl) ?>" rel="noopener">App Store</a>
      </div>
    </div>
  </footer>
</body>
</html>
