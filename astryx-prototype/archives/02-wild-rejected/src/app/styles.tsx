export function Styles() {
  return <style>{`
    html {color-scheme: light;}
    body {margin: 0;}
    button,input,textarea {font:inherit;}
    .mos-app,.mos-attachment-sheet {
      --wild-ink:var(--color-text-primary);--wild-paper:var(--color-background-body);--wild-card:var(--color-background-card);--wild-lime:var(--color-accent);--wild-coral:var(--color-warning);--wild-blue:var(--color-info);--wild-sage:var(--color-success);--wild-serif:Georgia,'Times New Roman',serif;
      font-family:var(--font-family-body);color:var(--wild-ink);
    }
    .mos-app {height:100dvh;background:var(--wild-paper);overflow:hidden;align-items:center;}
    .mos-topbar {width:min(100%,var(--memoryos-width));height:5.5rem;min-height:5.5rem;padding-inline:var(--spacing-8);justify-content:space-between;border-bottom:var(--memoryos-line) solid var(--color-border);gap:var(--spacing-4);background:var(--wild-paper);}
    .wild-brand {color:var(--wild-ink);}
    .wild-brand > .wild-bloom {width:2rem;height:2rem;color:var(--wild-ink);}
    .wild-brand > .astryx-text {font-size:1.75rem;font-weight:850;letter-spacing:-.085em;line-height:1;}
    .wild-edition {font-size:.66rem;letter-spacing:.16em;font-weight:650;}
    .wild-top-language {font-size:.8rem;border:var(--memoryos-line) solid var(--color-border);border-radius:var(--radius-full);padding-inline:var(--spacing-4);min-height:var(--memoryos-touch);}
    .mos-workspace {height:calc(100dvh - 5.5rem);width:min(100%,var(--memoryos-width));padding:var(--spacing-6) var(--spacing-8) var(--spacing-6) 0;align-items:stretch;gap:var(--spacing-6);min-height:0;}
    [dir=rtl] .mos-workspace {padding:var(--spacing-6) 0 var(--spacing-6) var(--spacing-8);}
    .mos-dock {width:13rem;min-width:13rem;padding:var(--spacing-6) var(--spacing-4);background:var(--wild-ink);color:var(--wild-paper);border-radius:0 1.75rem 1.75rem 0;align-items:stretch;}
    [dir=rtl] .mos-dock {border-radius:1.75rem 0 0 1.75rem;}
    .mos-dock-item.astryx-button {color:inherit;min-height:3.5rem;padding:var(--spacing-3) var(--spacing-4);border-radius:var(--spacing-3);background:transparent;justify-content:flex-start;border:0;}
    .wild-dock-content {width:100%;flex-direction:row;gap:var(--spacing-4);justify-content:flex-start;align-items:center;font-size:.95rem;font-weight:550;}
    .mos-dock-item .astryx-icon {color:inherit;}
    .mos-dock-item[aria-current=page] {background:var(--wild-lime);color:var(--wild-ink);}
    .wild-nav-foot {margin-top:auto;padding:var(--spacing-6) var(--spacing-4) var(--spacing-2);color:var(--wild-paper);}
    .wild-nav-foot > .wild-bloom {width:4.25rem;height:4.25rem;color:var(--wild-coral);transform:rotate(12deg);margin-bottom:var(--spacing-6);}
    .wild-nav-foot > .astryx-text {font-size:.8rem;line-height:1.6;white-space:pre-line;}
    .wild-nav-foot .wild-kicker {font-size:.52rem;opacity:.6;margin-top:var(--spacing-4);}
    .mos-shell {height:100%;flex:1;min-width:0;min-height:0;}
    .mos-header {padding:var(--spacing-4) 0 var(--spacing-6);flex-shrink:0;}
    .mos-title {font-size:clamp(1.75rem,3vw,2.6rem);font-weight:760;letter-spacing:-.06em;line-height:1.1;overflow-wrap:anywhere;}
    .mos-header-home .mos-title {position:absolute;width:1rem;height:1rem;overflow:hidden;clip-path:inset(50%);white-space:nowrap;}
    .mos-header-home {padding-block:var(--spacing-3) var(--spacing-4);}
    .wild-kicker {font-size:.64rem;font-weight:650;letter-spacing:.12em;line-height:1.55;}
    .mos-between {justify-content:space-between;width:100%;gap:var(--spacing-3);}
    .mos-content {min-height:0;}
    .mos-main {padding:0 var(--spacing-1) var(--spacing-6);min-height:100%;}
    .mos-search {padding-top:var(--spacing-4);}
    .wild-search-toggle {border:var(--memoryos-line) solid var(--color-border);border-radius:var(--radius-full);}
    .mos-capture {width:100%;}
    .wild-home-layout {display:grid;grid-template-columns:minmax(0,1.3fr) minmax(0,1fr);align-items:start;}
    .wild-hero {position:relative;min-height:32rem;overflow:hidden;background:var(--wild-ink);color:var(--wild-paper);border-radius:1.75rem;padding:var(--spacing-6);isolation:isolate;}
    .wild-hero-top {position:relative;z-index:2;justify-content:space-between;gap:var(--spacing-4);}
    .wild-hero .wild-kicker {font-size:.6rem;color:var(--wild-lime);max-width:70%;}
    .wild-serial {font-size:.75rem;font-weight:550;}
    .wild-hero-title {font-size:clamp(5.5rem,9vw,8.75rem);letter-spacing:-.075em;font-weight:780;line-height:.88;margin-top:var(--spacing-10);position:relative;z-index:2;}
    .wild-hero-title > .astryx-text {display:block;line-height:inherit;color:inherit;}
    .wild-italic {display:block;font-family:var(--wild-serif);font-style:italic;font-weight:400;letter-spacing:-.055em;line-height:1.04;}
    [dir=rtl] .wild-italic {font-family:var(--font-family-body);font-style:normal;font-weight:500;letter-spacing:-.035em;line-height:1.2;}
    .wild-hero-title .wild-italic {color:var(--wild-lime);margin-top:var(--spacing-2);}
    .wild-hero-copy {position:absolute;bottom:var(--spacing-8);inset-inline-start:var(--spacing-6);font-size:.9rem;line-height:1.55;white-space:pre-line;max-width:46%;}
    .wild-record-wrap {width:var(--memoryos-record-size);height:calc(var(--memoryos-record-size) + 1.75rem);position:absolute;bottom:var(--spacing-6);inset-inline-end:var(--spacing-6);z-index:3;align-items:center;}
    .wild-record-wrap > .wild-bloom {width:var(--memoryos-record-size);height:var(--memoryos-record-size);color:var(--wild-lime);animation:bloom-turn 40s linear infinite;}
    .wild-record-wrap > .is-recording {color:var(--wild-coral);animation-duration:9s;}
    .mos-record.astryx-button {position:absolute;top:0;inset-inline-start:0;width:var(--memoryos-record-size);height:var(--memoryos-record-size);min-height:var(--memoryos-record-size);color:var(--wild-ink);background:transparent;border:0;border-radius:var(--radius-full);box-shadow:none;padding:0;}
    .mos-record .mos-mic {width:3.25rem;height:3.25rem;color:var(--wild-ink);stroke-width:1.5;}
    .wild-record-caption {font-size:.58rem;letter-spacing:.13em;font-weight:650;margin-top:var(--spacing-3);color:var(--wild-paper);font-variant-numeric:tabular-nums;}
    .wild-scribble {position:absolute;top:4.5rem;inset-inline-end:var(--spacing-5);width:5rem;height:5rem;color:var(--wild-coral);transform:rotate(12deg);opacity:.9;}
    [dir=rtl] .wild-scribble {transform:scaleX(-1) rotate(12deg);}
    .wild-wave {position:absolute;bottom:var(--spacing-8);inset-inline-start:var(--spacing-6);height:3.5rem;align-items:center;max-width:48%;flex-wrap:wrap;}
    .wild-hero:has(.is-recording) .wild-hero-copy {visibility:hidden;}
    .wave-bar {width:.17rem;height:1.5rem;border-radius:var(--radius-full);background:var(--wild-lime);animation:voice-wave .7s ease-in-out infinite alternate;}
    .wave-bar:nth-child(3n) {height:2rem;}
    .wave-bar:nth-child(2n) {height:.7rem;}
    .wild-demo-voice {font-size:.57rem;width:100%;line-height:1.4;}
    .wild-threads {min-width:0;padding-top:var(--spacing-2);}
    .wild-tiny-number {font-size:.6rem;border:var(--memoryos-line) solid var(--wild-ink);border-radius:var(--radius-full);padding:.1rem .45rem;font-variant-numeric:tabular-nums;}
    .wild-note-rail {display:grid;grid-template-columns:1fr;gap:var(--spacing-4);padding:var(--spacing-2);}
    .wild-note-card {position:relative;padding:var(--spacing-5);border:0;min-height:12.5rem;text-align:start;align-items:stretch;justify-content:space-between;color:var(--wild-ink);cursor:pointer;border-radius:.25rem;transform:rotate(-2deg);transition:transform .25s ease;}
    .note-tone-0 {background:var(--color-background-orange);}
    .note-tone-1 {background:var(--color-background-green);transform:rotate(2deg);}
    .wild-note-text {font-size:clamp(1.3rem,2.5vw,1.8rem);font-weight:560;letter-spacing:-.045em;line-height:1.2;white-space:pre-line;display:-webkit-box;-webkit-line-clamp:3;-webkit-box-orient:vertical;overflow:hidden;overflow-wrap:anywhere;}
    .wild-note-bottom {font-size:.63rem;line-height:1.4;opacity:.8;}
    .mos-footer {padding:var(--spacing-4) 0 0;}
    .mos-composer {width:100%;padding:var(--spacing-2);min-height:4rem;border:var(--memoryos-line) solid var(--wild-ink);background:var(--wild-card);border-radius:var(--spacing-4);}
    .mos-composer-field {flex:1;min-width:0;width:0;}
    .mos-composer-control {border:0!important;background:transparent!important;box-shadow:none!important;}
    .mos-composer-control input {font-size:1rem!important;background:transparent;padding-inline:var(--spacing-2);min-width:0;}
    .mos-send.astryx-button {border-radius:var(--spacing-3);background:var(--wild-ink);color:var(--wild-paper);min-width:var(--memoryos-touch);min-height:var(--memoryos-touch);}
    .mos-send .astryx-icon {color:inherit;}
    .mos-send[data-disabled] {opacity:.35;}
    .wild-editorial-intro {position:relative;justify-content:space-between;align-items:center;min-height:7rem;gap:var(--spacing-4);}
    .wild-editorial-intro h2 {font-size:clamp(2.3rem,4vw,3.9rem);line-height:.98;font-weight:650;letter-spacing:-.07em;}
    .wild-outline-count {font-size:7.5rem;letter-spacing:-.13em;font-weight:800;line-height:.85;color:transparent;-webkit-text-stroke:var(--memoryos-line) var(--wild-ink);padding-inline-end:var(--spacing-2);}
    .wild-people-grid {display:grid;grid-template-columns:minmax(0,1fr) minmax(0,1fr);}
    .wild-person-card {position:relative;min-height:21rem;text-align:start;padding:var(--spacing-5);color:var(--wild-ink);border:0;border-radius:1.25rem;overflow:hidden;cursor:pointer;align-items:stretch;transition:transform .25s ease;}
    .person-ali {background:var(--color-background-blue);--portrait-shirt:var(--wild-blue);}
    .person-sara {background:var(--color-background-orange);--portrait-shirt:var(--wild-coral);}
    .person-omar {background:var(--color-background-green);--portrait-shirt:var(--wild-ink);}
    .wild-person-card.person-ali {grid-column:span 2;min-height:17.5rem;}
    .wild-person-top {justify-content:space-between;align-items:flex-start;position:relative;z-index:2;gap:var(--spacing-2);}
    .wild-person-top .wild-kicker {font-size:.56rem;max-width:75%;}
    .wild-person-art {position:relative;height:12rem;overflow:hidden;flex-shrink:0;align-items:center;justify-content:flex-end;}
    .wild-portrait {width:100%;height:100%;max-width:13rem;position:relative;z-index:1;flex-shrink:0;}
    .portrait-skin {fill:var(--wild-card);}
    .portrait-shirt {fill:var(--portrait-shirt,var(--wild-blue));}
    .portrait-hair {fill:var(--wild-ink);}
    .portrait-ink {stroke:var(--wild-ink);}
    .portrait-seam {stroke:var(--wild-card);opacity:.35;}
    .wild-person-initial {position:absolute;top:var(--spacing-3);inset-inline-start:0;font-size:6rem;letter-spacing:-.1em;line-height:1;color:transparent;-webkit-text-stroke:var(--memoryos-line) var(--wild-ink);opacity:.2;}
    .wild-person-card.person-ali .wild-person-art {position:absolute;inset-inline-end:var(--spacing-3);bottom:0;height:92%;width:47%;}
    .wild-person-card.person-ali .wild-portrait {max-width:16rem;}
    .wild-person-card.person-ali .wild-person-initial {display:none;}
    .wild-person-caption {margin-top:auto;z-index:2;position:relative;padding-top:var(--spacing-4);}
    .wild-person-card.person-ali .wild-person-caption {max-width:52%;padding-bottom:var(--spacing-3);}
    .wild-person-name {font-size:1.4rem;font-weight:650;line-height:1.12;letter-spacing:-.05em;overflow-wrap:anywhere;}
    .wild-person-card.person-ali .wild-person-name {font-size:clamp(2rem,4vw,3.5rem);}
    .wild-person-context {font-size:.8rem;line-height:1.5;display:-webkit-box;-webkit-line-clamp:2;-webkit-box-orient:vertical;overflow:hidden;}
    .wild-footnote {font-size:.8rem;line-height:1.65;padding-block:var(--spacing-2);}
    .wild-mini-stamp {width:5.5rem;height:5.5rem;flex-shrink:0;display:flex;align-items:center;justify-content:center;text-align:center;background:var(--wild-lime);color:var(--wild-ink);border-radius:var(--radius-full);transform:rotate(12deg);font-size:.6rem;font-weight:700;line-height:1.5;white-space:pre-line;letter-spacing:.05em;}
    .wild-project-grid {display:grid;grid-template-columns:minmax(0,1fr) minmax(0,1fr);align-items:start;}
    .wild-project-card {text-align:start;border:0;padding:0;background:transparent;align-items:stretch;cursor:pointer;min-width:0;}
    .wild-project-art {position:relative;min-height:15rem;border-radius:1.25rem;overflow:hidden;justify-content:center;align-items:center;}
    .art-website {background:var(--wild-blue);color:var(--wild-card);}
    .art-reading {background:var(--wild-coral);color:var(--wild-ink);}
    .wild-project-art-label {position:absolute;top:var(--spacing-5);inset-inline:var(--spacing-5);justify-content:space-between;z-index:1;}
    .wild-project-art-label .wild-kicker {font-size:.55rem;}
    .project-art {width:100%;height:auto;display:block;transform:translateY(var(--spacing-3)) rotate(-3deg);transition:transform .35s ease;}
    .art-browser {opacity:.65;}
    .art-browser-sticker,.art-star {fill:var(--wild-lime);}
    .art-sticker-ink {stroke:var(--wild-ink);}
    .art-shadow {fill:var(--wild-ink);opacity:.13;}
    .art-book {fill:var(--wild-paper);}
    .art-book-spine,.art-book-lines {stroke:var(--wild-ink);}
    .wild-project-caption {padding:var(--spacing-5) var(--spacing-1) var(--spacing-3);justify-content:space-between;align-items:start;gap:var(--spacing-4);}
    .wild-project-caption > :first-child {min-width:0;}
    .wild-project-name {font-size:1.65rem;font-weight:650;line-height:1.15;letter-spacing:-.06em;}
    .wild-project-caption .astryx-text[data-color=secondary] {font-size:.8rem;line-height:1.55;}
    .wild-project-number {font-size:1.35rem;font-weight:550;line-height:1;}
    .wild-project-number > .astryx-text {font-size:.6rem;display:block;font-weight:400;line-height:1.5;text-align:end;margin-top:var(--spacing-1);}
    .wild-birthdays-screen {max-width:52rem;}
    .wild-birthday-poster {padding:var(--spacing-6);position:relative;background:var(--wild-lime);border:0;border-radius:1.5rem;color:var(--wild-ink);overflow:hidden;align-items:stretch;min-height:27rem;text-align:start;cursor:pointer;}
    .wild-birthday-number {font-size:clamp(10rem,24vw,17rem);font-weight:700;line-height:.8;letter-spacing:-.12em;position:relative;z-index:2;margin-top:var(--spacing-8);}
    .wild-birthday-month {font-family:var(--wild-serif);font-style:italic;font-size:2.8rem;letter-spacing:-.06em;margin-top:var(--spacing-4);z-index:2;}
    .wild-birthday-person {margin-top:auto;padding-top:var(--spacing-6);position:relative;z-index:2;gap:var(--spacing-3);}
    .wild-birthday-person > :last-child > :first-child {font-size:1.45rem;font-weight:700;letter-spacing:-.05em;}
    .wild-birthday-person .wild-italic {font-size:1.35rem;}
    .wild-birthday-avatar {width:3.75rem;height:3.75rem;overflow:hidden;border-radius:var(--radius-full);background:var(--wild-card);padding-top:var(--spacing-1);--portrait-shirt:var(--wild-blue);flex-shrink:0;}
    .wild-birthday-avatar .wild-portrait {width:4rem;height:4.5rem;}
    .birthday-bloom {position:absolute;inset-inline-end:-4rem;top:6.5rem;width:16rem;height:16rem;color:var(--wild-coral);transform:rotate(12deg);}
    .wild-birthday-spark {position:absolute;inset-inline-end:var(--spacing-7);bottom:var(--spacing-7);font-size:5rem;line-height:1;transform:rotate(-13deg);}
    .wild-next-birthday {min-height:6.5rem;width:100%;text-align:start;background:transparent;border:0;border-block:var(--memoryos-line) solid var(--color-border);padding:var(--spacing-4) 0;gap:var(--spacing-5);cursor:pointer;color:inherit;}
    .wild-next-day {font-size:3rem;font-family:var(--wild-serif);font-style:italic;letter-spacing:-.07em;width:4rem;flex-shrink:0;}
    .wild-next-birthday > :last-child {margin-inline-start:auto;}
    .route-brainmap .mos-shell {background:var(--wild-ink);color:var(--wild-paper);border-radius:1.75rem;padding:var(--spacing-5) var(--spacing-6);}
    .route-brainmap.has-detail .mos-shell {background:var(--wild-paper);color:var(--wild-ink);}
    .route-brainmap:not(.has-detail) .mos-title,.route-brainmap:not(.has-detail) .mos-header .astryx-icon {color:var(--wild-paper);}
    .route-brainmap:not(.has-detail) .mos-header .wild-kicker {color:var(--wild-lime);}
    .mos-map-screen {min-width:0;padding-block:var(--spacing-2);}
    .mos-map-tools {justify-content:space-between;gap:var(--spacing-4);align-items:start;}
    .mos-map-tools h2 {font-size:clamp(2.1rem,4.5vw,3.9rem);color:var(--wild-paper);font-weight:600;letter-spacing:-.055em;line-height:1;}
    .mos-map-tools .wild-italic {color:var(--wild-lime);}
    .wild-map-toggle.astryx-button {border:var(--memoryos-line) solid color-mix(in srgb,var(--wild-paper) 35%,transparent);border-radius:var(--radius-full);color:var(--wild-paper);}
    .wild-map-toggle .astryx-icon {color:inherit;}
    .mos-graph {height:29rem;position:relative;min-height:24rem;isolation:isolate;}
    .mos-graph-lines {position:absolute;inset:0;width:100%;height:100%;overflow:visible;}
    .orbit-guides {stroke:var(--wild-paper);stroke-width:.14;fill:none;opacity:.16;stroke-dasharray:.7 1.5;}
    .orbit-links {stroke:var(--wild-paper);stroke-width:.2;fill:none;opacity:.6;}
    .orbit-dots {fill:var(--wild-coral);}
    [dir=rtl] .mos-graph-lines {transform:scaleX(-1);}
    .mos-node {position:absolute;width:8rem;transform:translate(-50%,-50%);align-items:center;gap:var(--spacing-3);padding:var(--spacing-2);color:var(--wild-paper);background:transparent;border:0;cursor:pointer;}
    [dir=rtl] .mos-node {transform:translate(50%,-50%);}
    .mos-node-symbol {position:relative;width:4.1rem;height:4.1rem;border-radius:var(--radius-full);background:var(--wild-paper);color:var(--wild-ink);align-items:center;justify-content:center;transition:transform .25s ease;}
    .mos-node-symbol > .astryx-icon {position:relative;z-index:2;color:inherit;width:1.8rem;height:1.8rem;stroke-width:1.5;}
    .node-ali .mos-node-symbol {background:var(--wild-coral);}
    .node-sara .mos-node-symbol {background:var(--wild-sage);}
    .node-website .mos-node-symbol {background:var(--wild-blue);color:var(--wild-paper);}
    .node-reading .mos-node-symbol {background:var(--color-background-orange);}
    .mos-node-you .mos-node-symbol {width:5.5rem;height:5.5rem;background:transparent;color:var(--wild-ink);}
    .mos-node-you .wild-bloom {position:absolute;inset:0;width:100%;height:100%;color:var(--wild-lime);animation:bloom-turn 55s linear infinite;}
    .mos-node[aria-pressed=true] .mos-node-symbol {outline:.125rem solid var(--wild-lime);outline-offset:var(--spacing-1);}
    .mos-node-name {font-size:.73rem;text-align:center;font-weight:500;line-height:1.3;background:var(--wild-ink);color:var(--wild-paper);padding:var(--spacing-1) var(--spacing-2);border-radius:var(--spacing-2);}
    .mos-node-detail {background:var(--wild-lime);color:var(--wild-ink);padding:var(--spacing-5);border-radius:var(--spacing-4);}
    .mos-node-detail .astryx-text {color:inherit;}
    .wild-solid-button.astryx-button {background:var(--wild-ink);color:var(--wild-paper);border-radius:var(--radius-full);align-self:flex-start;}
    .mos-map-caption {color:var(--wild-paper);opacity:.65;font-size:.75rem;text-align:center;line-height:1.5;}
    .wild-map-list .mos-row {color:var(--wild-paper);border-color:color-mix(in srgb,var(--wild-paper) 25%,transparent);}
    .wild-map-list .mos-row-sub {color:var(--wild-paper);opacity:.7;}
    .mos-detail {max-width:48rem;padding:var(--spacing-4) 0 var(--spacing-8);}
    .mos-detail > .wild-project-art {width:100%;max-width:35rem;min-height:16rem;}
    .mos-detail > .wild-project-art .project-art {max-width:30rem;}
    .wild-detail-portrait {width:7rem;height:8rem;overflow:hidden;flex-shrink:0;border-radius:1.1rem;}
    .mos-detail .astryx-text {line-height:1.65;}
    .mos-row {width:100%;text-align:start;border:0;border-bottom:var(--memoryos-line) solid var(--color-border);padding:var(--spacing-5) 0;background:transparent;cursor:pointer;color:inherit;min-height:5rem;}
    .mos-row-copy {flex:1;min-width:0;align-items:flex-start;text-align:start;}
    .mos-row-label {font-size:1.1rem;font-weight:580;letter-spacing:-.035em;overflow-wrap:anywhere;line-height:1.3;}
    .mos-row-sub {font-size:.85rem;line-height:1.5;text-align:start;}
    .mos-chevron {margin-inline-start:auto;flex-shrink:0;color:inherit;}
    .mos-section-label {font-size:.65rem;letter-spacing:.1em;text-transform:uppercase;font-weight:600;}
    .mos-section-heading {font-size:1.5rem;line-height:1.25;font-weight:650;letter-spacing:-.05em;}
    .mos-detail-heading {font-size:2.8rem;line-height:1.05;font-weight:650;letter-spacing:-.06em;}
    .mos-source {align-self:flex-start;justify-content:flex-start;text-align:start;max-width:100%;padding-inline:0;font-size:.9rem;text-decoration:underline;text-decoration-thickness:var(--memoryos-line);text-underline-offset:.25rem;}
    .mos-original {font-family:var(--wild-serif);font-size:clamp(1.45rem,3vw,2rem);line-height:1.65!important;white-space:pre-wrap;overflow-wrap:anywhere;}
    [dir=rtl] .mos-original {font-family:var(--font-family-body);}
    .mos-quote {font-family:var(--wild-serif);font-style:italic;font-size:2rem;line-height:1.4!important;letter-spacing:-.04em;}
    .mos-date {align-items:center;gap:var(--spacing-1);}
    .mos-date-large {min-width:8rem;min-height:9rem;align-items:flex-start;background:var(--wild-coral);padding:var(--spacing-4);border-radius:var(--spacing-4);transform:rotate(-3deg);}
    .mos-date-large .mos-date-day {font-size:5.5rem;font-weight:700;letter-spacing:-.1em;line-height:1;}
    .mos-date > :first-child {font-size:.75rem;line-height:1.3;}
    .mos-reminder {background:var(--wild-lime);padding:var(--spacing-5);border-radius:var(--spacing-4);color:var(--wild-ink);}
    .mos-reminder .astryx-text {color:inherit;}
    .wild-settings {padding-top:var(--spacing-6);}
    .settings-bloom {width:6rem;height:6rem;color:var(--wild-coral);transform:rotate(-10deg);}
    .wild-settings-title {font-size:clamp(3rem,7vw,5rem);letter-spacing:-.065em;line-height:1;}
    .wild-language-choice {border-radius:var(--radius-full);min-height:var(--memoryos-touch);}
    .mos-empty {padding:var(--spacing-8) 0;align-items:flex-start;}
    .mos-notice {position:fixed;z-index:30;bottom:7rem;left:50%;transform:translateX(-50%);width:max-content;max-width:calc(100% - 2rem);padding:var(--spacing-3) var(--spacing-5);border:var(--memoryos-line) solid var(--wild-ink);border-radius:var(--radius-full);background:var(--wild-lime);color:var(--wild-ink);pointer-events:none;}
    .mos-notice .astryx-text {font-size:.8rem;}
    .mos-attachment-sheet {width:min(100%,35rem)!important;margin-inline:auto!important;}
    button:focus-visible {outline:.1875rem solid var(--wild-blue);outline-offset:var(--spacing-1);}
    .route-brainmap button:focus-visible {outline-color:var(--wild-lime);}
    ::view-transition-old(root) {animation:wild-exit .18s ease both;}
    ::view-transition-new(root) {animation:wild-enter .3s cubic-bezier(.22,1,.36,1) both;}
    @keyframes bloom-turn {to {transform:rotate(360deg);}}
    @keyframes voice-wave {from {transform:scaleY(.35);}to {transform:scaleY(1);}}
    @keyframes wild-exit {to {opacity:0;transform:scale(.985);}}
    @keyframes wild-enter {from {opacity:0;transform:translateY(.7rem);}to {opacity:1;transform:translateY(0);}}
    @media (hover:hover) {
      .wild-note-card:hover {transform:rotate(0deg) translateY(-.2rem);}
      .wild-person-card:hover {transform:translateY(-.2rem) rotate(-.5deg);}
      .wild-project-card:hover .project-art {transform:translateY(0) rotate(1deg);}
      .mos-node:hover .mos-node-symbol {transform:scale(1.08);}
      .mos-dock-item:not([aria-current]):hover {background:color-mix(in srgb,var(--wild-paper) 12%,transparent);}
    }
    @media (min-width:70rem) {
      .wild-birthdays-screen {display:grid;grid-template-columns:1.25fr 1fr;align-items:start;}
      .wild-birthday-poster {grid-row:span 2;}
    }
    @media (max-width:60rem) {
      .wild-home-layout {grid-template-columns:1fr;}
      .wild-hero {min-height:23rem;}
      .wild-hero-title {font-size:6.5rem;margin-top:var(--spacing-6);}
      .wild-note-rail {grid-template-columns:minmax(0,1fr) minmax(0,1fr);gap:var(--spacing-3);}
      .wild-note-card {min-height:11rem;padding:var(--spacing-4);}
      .wild-note-card:nth-child(3) {grid-column:span 2;min-height:8rem;}
      .wild-note-text {font-size:1.35rem;}
      .wild-note-bottom {font-size:.57rem;}
      .wild-project-grid {grid-template-columns:1fr;}
    }
    @media (max-width:46rem) {
      .mos-topbar {height:4rem;min-height:4rem;padding-inline:var(--spacing-5);}
      .wild-brand > .astryx-text {font-size:1.45rem;}
      .wild-brand > .wild-bloom {width:1.5rem;height:1.5rem;}
      .wild-edition {display:none;}
      .wild-top-language {font-size:.72rem;padding-inline:var(--spacing-3);border:0;}
      .mos-workspace,[dir=rtl] .mos-workspace {height:calc(100dvh - 4rem);padding:0 var(--spacing-5) calc(5.25rem + env(safe-area-inset-bottom));gap:0;}
      .mos-header {padding-block:var(--spacing-5) var(--spacing-6);}
      .mos-header-home {padding-block:var(--spacing-4);}
      .mos-title {font-size:1.9rem;}
      .mos-header .wild-kicker {font-size:.54rem;}
      .mos-main {padding:0 0 var(--spacing-6);}
      .mos-dock,[dir=rtl] .mos-dock {position:fixed;z-index:20;inset-inline:var(--spacing-4);bottom:max(var(--spacing-3),env(safe-area-inset-bottom));width:auto;min-width:0;height:4.25rem;display:flex;flex-direction:row;align-items:stretch;justify-content:space-around;padding:var(--spacing-1);gap:0;border-radius:1.25rem;border:var(--memoryos-line) solid color-mix(in srgb,var(--wild-paper) 20%,transparent);}
      .mos-dock-item.astryx-button {min-width:0;min-height:0;width:20%;padding:var(--spacing-2) var(--spacing-1);border-radius:1rem;justify-content:center;}
      .wild-dock-content {flex-direction:column;gap:.25rem;align-items:center;justify-content:center;font-size:.54rem;letter-spacing:-.025em;font-weight:550;line-height:1.2;}
      .wild-dock-content .astryx-icon {width:1.3rem;height:1.3rem;}
      .wild-nav-foot {display:none;}
      .wild-hero {min-height:21rem;border-radius:1.4rem;padding:var(--spacing-5);}
      .wild-hero-title {font-size:6.5rem;}
      .wild-hero-copy {inset-inline-start:var(--spacing-5);bottom:var(--spacing-6);font-size:.78rem;}
      .wild-hero .wild-kicker {font-size:.5rem;}
      .wild-record-wrap {inset-inline-end:var(--spacing-5);bottom:var(--spacing-4);}
      .wild-record-caption {font-size:.53rem;}
      .wild-threads {padding-top:0;}
      .wild-threads > .mos-between .wild-kicker {font-size:.58rem;}
      .mos-footer {padding-top:var(--spacing-3);}
      .mos-composer {min-height:3.5rem;padding:var(--spacing-1);border-radius:var(--spacing-4);}
      .mos-composer-control input {font-size:1rem!important;}
      .mos-send.astryx-button {min-width:2.7rem;min-height:2.7rem;}
      .wild-editorial-intro {min-height:5.5rem;}
      .wild-editorial-intro h2 {font-size:2.6rem;}
      .wild-outline-count {font-size:5.75rem;}
      .wild-person-card {min-height:19rem;padding:var(--spacing-4);}
      .wild-person-card.person-ali {min-height:15rem;}
      .wild-person-card.person-ali .wild-person-name {font-size:2rem;}
      .wild-person-art {height:10rem;}
      .wild-person-name {font-size:1.2rem;}
      .wild-person-context {font-size:.72rem;}
      .wild-person-top .wild-kicker {font-size:.46rem;letter-spacing:.09em;}
      .wild-person-initial {font-size:4.8rem;}
      .wild-mini-stamp {width:4.5rem;height:4.5rem;font-size:.5rem;}
      .wild-project-art {min-height:14rem;}
      .wild-project-name {font-size:1.45rem;}
      .wild-project-caption .astryx-text[data-color=secondary] {font-size:.8rem;}
      .wild-birthday-poster {padding:var(--spacing-5);min-height:26rem;}
      .wild-birthday-number {font-size:12rem;}
      .wild-birthday-month {font-size:2.5rem;}
      .birthday-bloom {width:15rem;height:15rem;inset-inline-end:-6rem;top:7rem;}
      .wild-birthday-spark {font-size:4rem;inset-inline-end:var(--spacing-5);}
      .route-brainmap .mos-shell {border-radius:0;padding:0;background:transparent;}
      .route-brainmap {background:var(--wild-ink);}
      .route-brainmap.has-detail {background:var(--wild-paper);}
      .mos-map-tools h2 {font-size:2.35rem;}
      .mos-graph {height:25rem;min-height:22rem;}
      .mos-node {width:7rem;gap:var(--spacing-2);}
      .mos-node-symbol {width:3.4rem;height:3.4rem;}
      .mos-node-you .mos-node-symbol {width:4.5rem;height:4.5rem;}
      .mos-node-symbol > .astryx-icon {width:1.5rem;height:1.5rem;}
      .mos-node-name {font-size:.62rem;}
      .mos-detail {padding-top:0;}
      .wild-detail-portrait {width:6rem;height:7rem;}
      .mos-detail > :first-child > .astryx-text {font-size:.9rem;line-height:1.5;}
      .mos-detail-heading {font-size:2.3rem;}
      .mos-notice {bottom:6.5rem;}
    }
    @media (max-width:23rem) {
      .mos-topbar {padding-inline:var(--spacing-4);}
      .mos-workspace,[dir=rtl] .mos-workspace {padding-inline:var(--spacing-4);}
      .wild-hero-title {font-size:5.5rem;}
      .wild-hero {--memoryos-record-size:7rem;min-height:20rem;}
      .wild-hero-copy {font-size:.7rem;max-width:45%;}
      .wild-scribble {width:4rem;inset-inline-end:var(--spacing-3);}
      .wild-note-text {font-size:1.12rem;}
      .wild-note-card {padding:var(--spacing-3);min-height:10rem;}
      .wild-editorial-intro h2 {font-size:2.1rem;}
      .wild-outline-count {font-size:4.75rem;}
      .wild-person-card.person-ali .wild-person-name {font-size:1.7rem;}
      .wild-person-context {font-size:.68rem;}
      .wild-person-top .wild-kicker {font-size:.42rem;}
      .wild-person-art {height:8rem;}
      .wild-person-card {min-height:16.5rem;padding:var(--spacing-3);}
      .wild-person-name {font-size:1.05rem;}
      .wild-mini-stamp {width:3.75rem;height:3.75rem;font-size:.45rem;}
      .wild-birthday-number {font-size:10rem;}
      .wild-birthday-month {font-size:2.2rem;}
      .wild-birthday-person .wild-italic {font-size:1.1rem;}
      .mos-map-tools h2 {font-size:2rem;}
      .mos-date-large {min-width:6.5rem;}
      .mos-date-large .mos-date-day {font-size:4.5rem;}
    }
    @media (prefers-reduced-motion:reduce) {
      *,*::before,*::after {animation:none!important;transition:none!important;scroll-behavior:auto!important;}
      ::view-transition-group(*),::view-transition-old(*),::view-transition-new(*) {animation:none!important;}
    }
  `}</style>;
}
