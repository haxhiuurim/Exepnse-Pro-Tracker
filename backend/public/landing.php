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
  <meta name="description" content="Expense is a calm expense tracker for iPhone. Know what’s left today, log fast, split trips with friends, and sync when you sign in.">
  <meta name="theme-color" content="#0E1C1A">
  <meta property="og:title" content="<?= htmlspecialchars($appName) ?>">
  <meta property="og:description" content="<?= htmlspecialchars($tagline) ?>">
  <meta property="og:type" content="website">
  <link rel="preconnect" href="https://fonts.googleapis.com">
  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
  <link href="https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:wght@400;500;600;700;800&display=swap" rel="stylesheet">
  <style>
    :root {
      --ink: #0E1C1A;
      --ink-soft: #1A302C;
      --tide: #0F9F74;
      --tide-soft: #C8F0DF;
      --seafoam: #3DDC97;
      --mist: #E2EBE7;
      --mist-deep: #D0DDD8;
      --foam: #EEF3F1;
      --foam-deep: #E4EDE9;
      --slate: #3D544E;
      --muted: #6E817A;
      --danger: #E85A4F;
      --surplus: #0F9F74;
      --hairline: #D3DFDA;
      --glow: #7CFFC4;
      --panel: #ffffff;
      --font: "Plus Jakarta Sans", ui-rounded, system-ui, sans-serif;
      --ease: cubic-bezier(0.22, 1, 0.36, 1);
      --radius-md: 16px;
      --radius-lg: 20px;
      --radius-hero: 28px;
    }

    *, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }
    html { scroll-behavior: smooth; }
    body {
      font-family: var(--font);
      color: var(--ink);
      background: var(--foam);
      line-height: 1.55;
      -webkit-font-smoothing: antialiased;
      overflow-x: hidden;
    }
    a { color: inherit; text-decoration: none; }

    .skip {
      position: absolute; left: -9999px; top: 0;
      background: var(--ink); color: #fff; padding: 0.75rem 1rem; z-index: 100;
    }
    .skip:focus { left: 1rem; top: 1rem; }

    /* Matches AtmosphereBackground */
    .atmosphere {
      position: fixed; inset: 0; z-index: -1; pointer-events: none;
      background:
        radial-gradient(ellipse 70% 50% at 8% -5%, rgba(15, 159, 116, 0.14), transparent 55%),
        radial-gradient(ellipse 50% 40% at 96% 4%, rgba(124, 255, 196, 0.12), transparent 50%),
        linear-gradient(180deg, var(--foam) 0%, var(--foam-deep) 55%, #DCE8E3 100%);
    }

    .wrap { width: min(1080px, calc(100% - 2.5rem)); margin-inline: auto; }

    /* ——— Nav ——— */
    .nav {
      display: flex; align-items: center; justify-content: space-between;
      padding: 1.15rem 0;
      animation: rise 0.65s var(--ease) both;
    }
    .brand {
      display: inline-flex; align-items: center; gap: 0.65rem;
      font-weight: 800; font-size: 1.2rem; letter-spacing: -0.03em;
    }
    .brand-mark {
      width: 34px; height: 34px; border-radius: 11px;
      background: linear-gradient(145deg, var(--ink), #143029);
      display: grid; place-items: center;
      box-shadow: 0 8px 18px rgba(14, 28, 26, 0.2);
    }
    .brand-mark svg { width: 16px; height: 16px; }
    .nav-links { display: flex; align-items: center; gap: 1.25rem; }
    .nav-links a {
      font-size: 0.88rem; font-weight: 600; color: var(--slate);
      transition: color 0.2s ease;
    }
    .nav-links a:hover, .nav-links a:focus-visible { color: var(--tide); }
    .nav-cta {
      display: inline-flex; align-items: center; min-height: 40px;
      padding: 0.4rem 1rem; border-radius: 14px;
      background: var(--ink); color: #fff !important;
      font-weight: 700; font-size: 0.82rem;
      transition: transform 0.18s ease, background 0.2s ease;
    }
    .nav-cta:hover { transform: translateY(-1px); background: var(--ink-soft); color: #fff !important; }

    /* ——— Hero: one composition ——— */
    .hero {
      min-height: calc(100svh - 5rem);
      display: grid; align-items: center;
      padding: 1.25rem 0 3.5rem; gap: 2.75rem;
    }
    @media (min-width: 900px) {
      .hero {
        grid-template-columns: 1fr 1fr;
        gap: 3rem;
        padding-top: 1.5rem;
      }
    }

    .hero-copy { animation: rise 0.8s var(--ease) 0.06s both; }
    .hero-brand {
      font-weight: 800;
      font-size: clamp(3.2rem, 8.5vw, 5.2rem);
      line-height: 0.92; letter-spacing: -0.055em;
      color: var(--ink); margin-bottom: 1rem;
    }
    .hero-headline {
      font-weight: 700;
      font-size: clamp(1.25rem, 2.8vw, 1.65rem);
      line-height: 1.25; letter-spacing: -0.025em;
      color: var(--ink-soft); max-width: 18ch; margin-bottom: 0.75rem;
    }
    .hero-support {
      font-size: 1.02rem; color: var(--muted);
      max-width: 34ch; margin-bottom: 1.6rem;
    }
    .cta-row { display: flex; flex-wrap: wrap; gap: 0.7rem; }
    .btn {
      display: inline-flex; align-items: center; justify-content: center; gap: 0.5rem;
      min-height: 52px; padding: 0.8rem 1.25rem; border-radius: var(--radius-md);
      font-weight: 700; font-size: 0.92rem;
      transition: transform 0.18s ease, background 0.2s ease;
    }
    .btn:hover { transform: translateY(-1px); }
    .btn:focus-visible { outline: 3px solid rgba(15, 159, 116, 0.4); outline-offset: 2px; }
    .btn-primary {
      background: var(--ink); color: #fff;
      box-shadow: 0 12px 28px rgba(14, 28, 26, 0.18);
    }
    .btn-primary:hover { background: var(--ink-soft); }
    .btn-secondary {
      background: var(--panel); color: var(--ink);
      border: 1.5px solid var(--hairline);
    }
    .btn-secondary:hover { background: #fff; border-color: var(--mist-deep); }
    .apple-icon { width: 17px; height: 17px; }

    .hero-visual {
      position: relative;
      animation: float-in 0.95s var(--ease) 0.14s both;
    }

    /* Phone frame — mirrors app Home spent hero */
    .phone {
      width: min(300px, 82vw);
      margin-inline: auto;
      border-radius: 36px;
      background: linear-gradient(165deg, #143029, var(--ink) 50%, var(--ink-soft));
      padding: 11px;
      box-shadow: 0 28px 56px rgba(14, 28, 26, 0.28);
      animation: float 7s ease-in-out infinite;
    }
    .phone-screen {
      border-radius: 28px;
      background: linear-gradient(180deg, var(--foam), var(--foam-deep));
      overflow: hidden;
      padding: 1.15rem 0.95rem 1rem;
      display: flex; flex-direction: column; gap: 0.75rem;
    }
    .phone-notch {
      width: 36%; height: 7px; border-radius: 999px;
      background: rgba(14, 28, 26, 0.1); margin: 0 auto 0.15rem;
    }

    .spent-hero {
      border-radius: var(--radius-hero);
      padding: 1.1rem 1rem 1rem;
      background:
        radial-gradient(circle at 110% -10%, rgba(124, 255, 196, 0.22), transparent 45%),
        radial-gradient(circle at -15% 110%, rgba(15, 159, 116, 0.28), transparent 42%),
        linear-gradient(145deg, var(--ink), #143029 48%, var(--ink-soft));
      color: #fff;
    }
    .spent-label {
      font-size: 0.62rem; font-weight: 700; letter-spacing: 0.1em;
      color: rgba(255,255,255,0.55); margin-bottom: 0.45rem;
      display: flex; align-items: center; gap: 0.4rem;
    }
    .spent-dot {
      width: 6px; height: 6px; border-radius: 50%;
      background: var(--glow); opacity: 0.7;
    }
    .spent-amount {
      font-size: 1.85rem; font-weight: 800; letter-spacing: -0.04em;
      line-height: 1; margin-bottom: 0.85rem;
    }
    .spent-meta {
      display: grid; grid-template-columns: 1fr 1fr; gap: 0.5rem;
      margin-bottom: 0.75rem;
    }
    .meta-chip {
      background: rgba(255,255,255,0.08);
      border-radius: 14px; padding: 0.55rem 0.65rem;
    }
    .meta-chip span {
      display: block; font-size: 0.58rem; font-weight: 700;
      letter-spacing: 0.08em; color: rgba(255,255,255,0.48);
      margin-bottom: 0.15rem;
    }
    .meta-chip strong {
      font-size: 0.82rem; font-weight: 700; color: var(--seafoam);
    }
    .period-chips { display: flex; gap: 0.35rem; }
    .period-chips span {
      flex: 1; text-align: center;
      font-size: 0.62rem; font-weight: 700;
      padding: 0.4rem 0; border-radius: 10px;
      color: rgba(255,255,255,0.55);
      background: rgba(255,255,255,0.06);
    }
    .period-chips span.on {
      color: var(--ink);
      background: #fff;
    }

    .money-row {
      display: grid; grid-template-columns: 1fr 1fr; gap: 0.55rem;
    }
    .money-tile {
      background: var(--panel);
      border-radius: var(--radius-md);
      padding: 0.7rem 0.75rem;
      box-shadow: 0 6px 14px rgba(14, 28, 26, 0.04);
    }
    .money-tile span {
      display: block; font-size: 0.6rem; font-weight: 700;
      letter-spacing: 0.06em; color: var(--muted); margin-bottom: 0.2rem;
    }
    .money-tile strong {
      font-size: 0.95rem; font-weight: 800; letter-spacing: -0.02em;
    }
    .money-tile .jade { color: var(--tide); }
    .money-tile .ink { color: var(--ink); }

    .txn {
      display: flex; align-items: center; gap: 0.6rem;
      padding: 0.6rem 0.65rem; background: var(--panel); border-radius: 14px;
      box-shadow: 0 4px 12px rgba(14, 28, 26, 0.04);
    }
    .txn-icon {
      width: 30px; height: 30px; border-radius: 10px;
      display: grid; place-items: center; flex-shrink: 0;
    }
    .txn-icon svg { width: 14px; height: 14px; }
    .txn-meta { flex: 1; min-width: 0; }
    .txn-meta strong {
      display: block; font-size: 0.76rem; font-weight: 700; color: var(--ink);
    }
    .txn-meta span { font-size: 0.64rem; color: var(--muted); }
    .txn-amt { font-size: 0.76rem; font-weight: 700; }
    .txn-amt.out { color: var(--danger); }

    /* ——— Sections ——— */
    section { padding: 4.25rem 0; }
    .section-eyebrow {
      font-size: 0.72rem; font-weight: 800; letter-spacing: 0.1em;
      color: var(--tide); margin-bottom: 0.55rem; text-transform: uppercase;
    }
    .section-head { max-width: 34rem; margin-bottom: 2rem; }
    .section-head h2 {
      font-size: clamp(1.65rem, 3.4vw, 2.2rem);
      font-weight: 800; letter-spacing: -0.035em; line-height: 1.15;
      margin-bottom: 0.55rem;
    }
    .section-head p { color: var(--muted); font-size: 1rem; }

    .features {
      display: grid; gap: 0.85rem;
    }
    @media (min-width: 700px) {
      .features { grid-template-columns: repeat(3, 1fr); }
    }

    .feature {
      padding: 1.25rem 1.2rem 1.35rem;
      border-radius: var(--radius-lg);
      background: var(--panel);
      box-shadow: 0 8px 20px rgba(14, 28, 26, 0.04);
      transition: transform 0.22s var(--ease);
      animation: rise 0.65s var(--ease) both;
    }
    .feature:nth-child(1) { animation-delay: 0.04s; }
    .feature:nth-child(2) { animation-delay: 0.1s; }
    .feature:nth-child(3) { animation-delay: 0.16s; }
    .feature:nth-child(4) { animation-delay: 0.22s; }
    .feature:nth-child(5) { animation-delay: 0.28s; }
    .feature:nth-child(6) { animation-delay: 0.34s; }
    .feature:hover { transform: translateY(-2px); }
    .feature-icon {
      width: 40px; height: 40px; border-radius: 12px;
      background: var(--tide-soft); color: var(--tide);
      display: grid; place-items: center; margin-bottom: 0.9rem;
    }
    .feature-icon svg { width: 18px; height: 18px; }
    .feature h3 {
      font-size: 1rem; font-weight: 750; font-weight: 700;
      letter-spacing: -0.02em; margin-bottom: 0.35rem;
    }
    .feature p { font-size: 0.9rem; color: var(--muted); }

    .how { display: grid; gap: 0.85rem; }
    @media (min-width: 800px) { .how { grid-template-columns: repeat(3, 1fr); } }
    .step {
      padding: 1.35rem 1.25rem;
      border-radius: var(--radius-lg);
      background: var(--panel);
      box-shadow: 0 8px 20px rgba(14, 28, 26, 0.04);
    }
    .step-num {
      font-size: 0.72rem; font-weight: 800; letter-spacing: 0.08em;
      color: var(--tide); margin-bottom: 0.65rem;
    }
    .step h3 {
      font-size: 1.08rem; font-weight: 700;
      letter-spacing: -0.02em; margin-bottom: 0.35rem;
    }
    .step p { color: var(--muted); font-size: 0.92rem; }

    /* Download — banking hero panel */
    .download {
      padding: 2rem 1.75rem;
      border-radius: var(--radius-hero);
      color: #fff;
      display: grid; gap: 1.35rem;
      position: relative; overflow: hidden;
      background:
        radial-gradient(circle at 105% -20%, rgba(124, 255, 196, 0.2), transparent 40%),
        radial-gradient(circle at -10% 120%, rgba(15, 159, 116, 0.3), transparent 40%),
        linear-gradient(145deg, var(--ink), #143029 50%, var(--ink-soft));
      box-shadow: 0 20px 40px rgba(14, 28, 26, 0.2);
      animation: rise 0.7s var(--ease) both;
    }
    @media (min-width: 800px) {
      .download {
        grid-template-columns: 1.35fr 0.65fr;
        align-items: center;
        padding: 2.35rem 2.4rem;
      }
    }
    .download h2 {
      font-size: clamp(1.45rem, 2.8vw, 1.9rem);
      font-weight: 800; letter-spacing: -0.03em; margin-bottom: 0.45rem;
      position: relative;
    }
    .download p {
      color: rgba(255,255,255,0.7); font-size: 0.95rem;
      max-width: 38ch; position: relative;
    }
    .download .btn-primary {
      background: #fff; color: var(--ink);
      box-shadow: none;
      position: relative;
    }
    .download .btn-primary:hover { background: var(--tide-soft); }

    footer {
      padding: 2.25rem 0 2.75rem;
      border-top: 1px solid var(--hairline);
      color: var(--muted); font-size: 0.86rem;
    }
    .footer-row {
      display: flex; flex-wrap: wrap; gap: 1rem;
      justify-content: space-between; align-items: center;
    }
    .footer-links { display: flex; gap: 1.2rem; }
    .footer-links a:hover, .footer-links a:focus-visible { color: var(--tide); }

    @keyframes rise {
      from { opacity: 0; transform: translateY(16px); }
      to { opacity: 1; transform: translateY(0); }
    }
    @keyframes float-in {
      from { opacity: 0; transform: translateY(24px) scale(0.97); }
      to { opacity: 1; transform: translateY(0) scale(1); }
    }
    @keyframes float {
      0%, 100% { transform: translateY(0); }
      50% { transform: translateY(-8px); }
    }

    @media (prefers-reduced-motion: reduce) {
      html { scroll-behavior: auto; }
      *, *::before, *::after { animation: none !important; transition: none !important; }
    }
    @media (max-width: 699px) {
      .nav-links a:not(.nav-cta) { display: none; }
      .hero { min-height: auto; padding-bottom: 2.5rem; }
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
          Know what’s left today. Log in seconds. Split trips fairly — calm money tracking for iPhone.
        </p>
        <div class="cta-row">
          <a class="btn btn-primary" href="<?= htmlspecialchars($appStoreUrl) ?>" rel="noopener">
            <svg class="apple-icon" viewBox="0 0 24 24" aria-hidden="true" fill="currentColor">
              <path d="M18.71 12.46c-.03-2.2 1.8-3.26 1.88-3.31-1.03-1.5-2.62-1.7-3.18-1.72-1.35-.14-2.64.8-3.32.8-.69 0-1.75-.78-2.88-.76-1.48.02-2.85.86-3.61 2.18-1.54 2.67-.39 6.62 1.11 8.79.73 1.06 1.61 2.25 2.76 2.21 1.11-.05 1.53-.71 2.87-.71s1.72.71 2.88.69c1.19-.02 1.95-1.08 2.68-2.15.84-1.23 1.18-2.42 1.2-2.48-.03-.01-2.3-.88-2.33-3.54zM15.4 5.18c.6-.73 1.01-1.75.9-2.76-.87.03-1.92.58-2.54 1.31-.56.65-1.05 1.69-.92 2.68 1 .08 2.02-.5 2.56-1.23z"/>
            </svg>
            Download on the App Store
          </a>
          <a class="btn btn-secondary" href="#features">See features</a>
        </div>
      </div>

      <div class="hero-visual" aria-hidden="true">
        <div class="phone">
          <div class="phone-screen">
            <div class="phone-notch"></div>
            <div class="spent-hero">
              <div class="spent-label">Spent this week <span class="spent-dot"></span></div>
              <div class="spent-amount">$428.60</div>
              <div class="spent-meta">
                <div class="meta-chip"><span>Income</span><strong>$2,400</strong></div>
                <div class="meta-chip"><span>Net</span><strong>+$1,971</strong></div>
              </div>
              <div class="period-chips">
                <span>Day</span><span class="on">Week</span><span>Month</span><span>Year</span>
              </div>
            </div>
            <div class="money-row">
              <div class="money-tile"><span>Available today</span><strong class="jade">$86</strong></div>
              <div class="money-tile"><span>Cash</span><strong class="ink">$1,240</strong></div>
            </div>
            <div class="txn">
              <div class="txn-icon" style="background:#FDE8E6;color:var(--danger)">
                <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round"><path d="M4 12h16"/></svg>
              </div>
              <div class="txn-meta"><strong>Groceries</strong><span>Today · Food</span></div>
              <div class="txn-amt out">−$64.20</div>
            </div>
            <div class="txn">
              <div class="txn-icon" style="background:var(--tide-soft);color:var(--tide)">
                <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round"><path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2"/><circle cx="9" cy="7" r="4"/></svg>
              </div>
              <div class="txn-meta"><strong>Weekend trip</strong><span>Shared · 3 people</span></div>
              <div class="txn-amt out">−$48.00</div>
            </div>
          </div>
        </div>
      </div>
    </section>

    <section id="features" class="wrap">
      <div class="section-head">
        <p class="section-eyebrow">Features</p>
        <h2>Built like the app you open every day</h2>
        <p>The same Obsidian + Jade language — Available Today, Quick Add, Trips, and sync when you sign in.</p>
      </div>
      <div class="features">
        <article class="feature">
          <div class="feature-icon">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="9"/><path d="M12 7v5l3 2"/></svg>
          </div>
          <h3>Available Today</h3>
          <p>Income, savings goals, and spend become a daily number you can trust before you buy.</p>
        </article>
        <article class="feature">
          <div class="feature-icon">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M12 5v14M5 12h14"/></svg>
          </div>
          <h3>Quick Add</h3>
          <p>Amount-first entry and natural language like “Coffee 4.50” so logging takes seconds.</p>
        </article>
        <article class="feature">
          <div class="feature-icon">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2"/><circle cx="9" cy="7" r="4"/><path d="M23 21v-2a4 4 0 0 0-3-3.87M16 3.13a4 4 0 0 1 0 7.75"/></svg>
          </div>
          <h3>Shared trips</h3>
          <p>Share a code, approve who joins, split fairly, and settle balances — no bank linking.</p>
        </article>
        <article class="feature">
          <div class="feature-icon">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M3 3v18h18"/><path d="M7 14l4-4 3 3 5-6"/></svg>
          </div>
          <h3>Insights</h3>
          <p>Category pulse, trends, budgets, and projections that show where money goes.</p>
        </article>
        <article class="feature">
          <div class="feature-icon">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M12 3v3M12 18v3M3 12h3M18 12h3"/><circle cx="12" cy="12" r="4"/></svg>
          </div>
          <h3>Account sync</h3>
          <p>Sign in to back up your ledger. Guest mode stays on this device only.</p>
        </article>
        <article class="feature">
          <div class="feature-icon">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="5" y="2" width="14" height="20" rx="3"/><path d="M9 18h6"/></svg>
          </div>
          <h3>Widgets</h3>
          <p>Home Screen spend summaries and trip widgets with one-tap add expense.</p>
        </article>
      </div>
    </section>

    <section id="how" class="wrap">
      <div class="section-head">
        <p class="section-eyebrow">How it works</p>
        <h2>Simple by design</h2>
        <p>Three steps from download to a clearer picture of your money.</p>
      </div>
      <div class="how">
        <article class="step">
          <div class="step-num">01</div>
          <h3>Download Expense</h3>
          <p>Open on iPhone, set your currency, and choose an account or continue as a guest.</p>
        </article>
        <article class="step">
          <div class="step-num">02</div>
          <h3>Log what you spend</h3>
          <p>Quick Add, receipts, or trip expenses. Categories and budgets stay organized.</p>
        </article>
        <article class="step">
          <div class="step-num">03</div>
          <h3>See what’s left</h3>
          <p>Available Today, insights, and trip balances help you keep more.</p>
        </article>
      </div>
    </section>

    <section id="download" class="wrap">
      <div class="download">
        <div>
          <h2>Ready when you are</h2>
          <p>Download Expense for iPhone — the same calm banking home you see here, on your lock screen widgets too.</p>
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
      <p>© <?= $year ?> <?= htmlspecialchars($appName) ?>. Calm expense tracking for iOS.</p>
      <div class="footer-links">
        <a href="#features">Features</a>
        <a href="#how">How it works</a>
        <a href="<?= htmlspecialchars($appStoreUrl) ?>" rel="noopener">App Store</a>
      </div>
    </div>
  </footer>
</body>
</html>
