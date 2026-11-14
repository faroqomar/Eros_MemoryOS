export function Styles() {
  return <style>{`
    html {color-scheme: light;}
    body {margin: 0;}
    button, input, textarea {font: inherit;}
    .mos-review {min-height: 100dvh; background: var(--color-background-body); color: var(--color-text-primary); font-family: var(--font-family-body); align-items: center;}
    .mos-review-bar {width: min(var(--memoryos-width), 100%); min-height: var(--spacing-12); padding-inline: var(--spacing-4); justify-content: space-between; flex-shrink: 0;}
    .mos-language {font-size: var(--font-size-sm);}
    .mos-phone {width: min(var(--memoryos-width), 100%); height: min(52rem, calc(100dvh - 7rem)); min-height: 32rem; position: relative; background: var(--color-background-surface); border: var(--memoryos-line) solid var(--color-border); overflow: hidden;}
    .mos-shell {height: 100%; min-height: 0; width: 100%;}
    .mos-header {padding: var(--spacing-5) var(--spacing-4) var(--spacing-2); flex-shrink: 0;}
    .mos-header > :first-child {width: 100%;}
    .mos-title {font-family: var(--font-family-heading); font-size: var(--font-size-2xl); font-weight: 650; letter-spacing: -.025em; line-height: 1.25; flex: 1; min-width: 0; overflow-wrap: anywhere;}
    .mos-menu-button {min-width: var(--memoryos-touch); min-height: var(--memoryos-touch);}
    .mos-content {min-height: 0;}
    .mos-main {min-height: 100%;}
    .mos-content-capture {display: flex; flex-direction: column;}
    .mos-content-capture .mos-main {flex: 1;}
    .mos-capture {flex: 1; height: 100%; min-height: 0;}
    .mos-record-area {position: relative; flex: 1; min-height: 18rem; align-items: center; justify-content: center; padding-bottom: var(--spacing-10);}
    .mos-record.astryx-button {width: var(--memoryos-record-size); height: var(--memoryos-record-size); min-height: var(--memoryos-record-size); border-radius: var(--radius-full); padding: 0; color: var(--color-on-accent); background: var(--color-background-inverted); box-shadow: none; border: 0;}
    .mos-record .mos-mic {color: var(--color-on-accent); width: calc(var(--memoryos-record-size) / 3.15); height: calc(var(--memoryos-record-size) / 3.15); stroke-width: 1.35;}
    .mos-is-recording .mos-mic {width: var(--spacing-8); height: var(--spacing-8); fill: currentColor; stroke-width: 0;}
    .mos-record-label {font-size: var(--font-size-lg); color: var(--color-text-primary);}
    .mos-record-state {position: absolute; top: calc(50% + 7.5rem); align-items: center;}
    .mos-timer {font-variant-numeric: tabular-nums;}
    .mos-footer {padding: var(--spacing-3) var(--spacing-4) max(var(--spacing-6), env(safe-area-inset-bottom));}
    .mos-composer {width: 100%; border: var(--memoryos-line) solid var(--color-border-emphasized); border-radius: var(--radius-full); padding: var(--spacing-1); background: var(--color-background-surface); min-height: calc(var(--memoryos-touch) + var(--spacing-2));}
    .mos-composer-field {flex: 1; min-width: 0; width: 0;}
    .mos-composer-control {border: 0 !important; box-shadow: none !important; background: transparent !important; outline-offset: 0; border-radius: 0; border-inline-start: var(--memoryos-line) solid var(--color-border) !important;}
    .mos-composer-control input {font-size: var(--font-size-lg); padding-inline: var(--spacing-3); background: transparent; min-width: 0;}
    .mos-send {border-radius: var(--radius-full); min-width: var(--spacing-10); min-height: var(--spacing-10);}
    .mos-send[data-disabled] {opacity: .55;}
    .mos-review-caption {padding: var(--spacing-4); font-size: var(--font-size-xs); text-align: center;}
    .mos-list-screen, .mos-detail, .mos-map-screen {padding: var(--spacing-6);}
    .mos-intro {margin-bottom: var(--spacing-8); font-size: var(--font-size-base);}
    .mos-row {width: 100%; text-align: start; border: 0; border-bottom: var(--memoryos-line) solid var(--color-border); padding: var(--spacing-5) 0; background: transparent; cursor: pointer; color: inherit; min-height: 5.5rem;}
    .mos-row-copy {flex: 1; min-width: 0; align-items: flex-start; text-align: start;}
    .mos-row-label {font-size: var(--font-size-lg); font-weight: 500; overflow: hidden; text-overflow: ellipsis; display: -webkit-box; -webkit-line-clamp: 2; -webkit-box-orient: vertical; line-height: 1.45; overflow-wrap: anywhere;}
    .mos-row-sub {font-size: var(--font-size-base); line-height: 1.5; text-align: start;}
    .mos-row-icon {flex-shrink: 0; color: var(--color-text-primary);}
    .mos-chevron {color: var(--color-text-secondary); flex-shrink: 0;}
    .mos-avatar {width: var(--spacing-12); height: var(--spacing-12); border: var(--memoryos-line) solid var(--color-border); border-radius: var(--radius-full); align-items: center; justify-content: center; flex-shrink: 0;}
    .mos-avatar-large {width: 4rem; height: 4rem;}
    .mos-date {width: var(--spacing-12); min-height: var(--spacing-12); align-items: center; gap: var(--spacing-0-5); flex-shrink: 0;}
    .mos-date > :first-child {font-size: var(--font-size-xs); color: var(--color-text-secondary);}
    .mos-date-day {font-size: var(--font-size-2xl); line-height: 1.15;}
    .mos-date-large {width: 4rem; min-height: 4rem;}
    .mos-date-large .mos-date-day {font-size: var(--font-size-3xl);}
    .mos-detail {padding-top: var(--spacing-8); padding-bottom: var(--spacing-10);}
    .mos-detail > :first-child {margin-top: 0;}
    .mos-detail .mos-row {min-height: 4.5rem; padding-block: var(--spacing-4);}
    .mos-section-heading {font-size: var(--font-size-lg); font-weight: 600; line-height: 1.5;}
    .mos-section-label {font-size: var(--font-size-sm); margin-bottom: var(--spacing-2);}
    .mos-detail-heading {font-size: var(--font-size-xl); font-weight: 600; line-height: 1.4;}
    .mos-detail .astryx-text {line-height: 1.65;}
    .mos-source {align-self: flex-start; justify-content: flex-start; text-align: start; min-height: var(--memoryos-touch); padding-inline: 0; font-size: var(--font-size-base); max-width: 100%;}
    .mos-original {font-size: var(--font-size-lg); line-height: 1.9 !important; white-space: pre-wrap; overflow-wrap: anywhere;}
    .mos-quote {font-size: var(--font-size-xl); line-height: 1.7 !important;}
    .mos-list-foot {padding-top: var(--spacing-8); line-height: 1.6;}
    .mos-search {padding-top: var(--spacing-3);}
    .mos-empty {align-items: flex-start; padding-block: var(--spacing-10);}
    .mos-reminder {padding: var(--spacing-5); background: var(--color-background-body); border-radius: var(--radius-2);}
    .mos-recent {padding: 0 var(--spacing-6); max-height: 14rem; overflow: auto; flex-shrink: 0;}
    .mos-recent .mos-row {min-height: 0; padding-block: var(--spacing-3);}
    .mos-recent .mos-row-label {font-size: var(--font-size-base); -webkit-line-clamp: 1;}
    .mos-recent .mos-row-sub {font-size: var(--font-size-sm);}
    .mos-notice {position: absolute; inset-inline: var(--spacing-6); bottom: 6rem; align-items: center; padding: var(--spacing-3) var(--spacing-4); background: var(--color-background-body); color: var(--color-text-primary); border: var(--memoryos-line) solid var(--color-border); border-radius: var(--radius-2); pointer-events: none; z-index: 5;}
    .mos-between {justify-content: space-between;}
    .mos-drawer {top: var(--spacing-12) !important; bottom: auto !important; height: min(52rem, calc(100dvh - 7rem)) !important; inset-inline-start: max(0rem, calc(50vw - 13.5rem)) !important; inset-inline-end: auto !important; border-radius: 0 !important;}
    .mos-drawer-inner {min-height: 100%; height: 100%; background: var(--color-background-surface);}
    .mos-drawer-header {padding: var(--spacing-6) var(--spacing-5); justify-content: space-between; gap: var(--spacing-4);}
    .mos-nav {padding: var(--spacing-5) var(--spacing-4);}
    .mos-nav-item {min-height: 3.75rem; padding-inline: var(--spacing-5); justify-content: flex-start; font-size: var(--font-size-xl); gap: var(--spacing-5); font-weight: 400;}
    .mos-nav-item[aria-current="page"] {background: var(--color-background-body);}
    .mos-nav-bottom {margin-top: auto; padding: var(--spacing-6) var(--spacing-4) max(var(--spacing-8), env(safe-area-inset-bottom));}
    .mos-map-tools {justify-content: space-between; gap: var(--spacing-2);}
    .mos-map-tools > :first-child {font-size: var(--font-size-base);}
    .mos-graph {position: relative; height: 24rem; min-height: 24rem; margin-block: var(--spacing-4);}
    .mos-graph-lines {position: absolute; inset: 0; width: 100%; height: 100%; overflow: visible;}
    .mos-graph-lines path {stroke: var(--color-border-emphasized); stroke-width: .3; fill: none;}
    [dir="rtl"] .mos-graph-lines {transform: scaleX(-1);}
    .mos-node {position: absolute; width: 7rem; transform: translate(-50%, -50%); align-items: center; gap: var(--spacing-2); padding: var(--spacing-2); color: inherit; border: 0; background: transparent; cursor: pointer;}
    [dir="rtl"] .mos-node {transform: translate(50%, -50%);}
    .mos-node-symbol {width: 3.5rem; height: 3.5rem; border-radius: var(--radius-full); border: var(--memoryos-line) solid var(--color-border-emphasized); background: var(--color-background-surface); align-items: center; justify-content: center;}
    .mos-node-you .mos-node-symbol, .mos-node[aria-pressed="true"] .mos-node-symbol {background: var(--color-background-inverted); color: var(--color-on-accent); border-color: var(--color-background-inverted);}
    .mos-node-name {font-size: var(--font-size-sm); text-align: center; background: var(--color-background-surface); line-height: 1.5;}
    .mos-node-detail {padding-top: var(--spacing-3); border-top: var(--memoryos-line) solid var(--color-border);}
    .mos-map-caption {text-align: center; padding-bottom: var(--spacing-4);}
    .mos-attachment-sheet {width: min(var(--memoryos-width), 100%) !important; margin-inline: auto !important;}
    button:focus-visible {outline: .125rem solid var(--color-text-primary); outline-offset: var(--spacing-1);}
    @media (hover: hover) {.mos-row:hover, .mos-node:hover .mos-node-symbol {background: var(--color-background-body);} .mos-row:hover {border-radius: var(--radius-1);}}
    @media (max-width: 36rem) {
      .mos-review {background: var(--color-background-surface);}
      .mos-review-bar {min-height: var(--memoryos-touch); border-bottom: var(--memoryos-line) solid var(--color-border);}
      .mos-phone {height: calc(100dvh - var(--memoryos-touch)); min-height: 0; border: 0;}
      .mos-review-caption {display: none;}
      .mos-header {padding-top: var(--spacing-4);}
      .mos-drawer {top: var(--memoryos-touch) !important; bottom: auto !important; height: calc(100dvh - var(--memoryos-touch)) !important; inset-inline-start: 0 !important;}
      .mos-record-area {min-height: 14rem;}
    }
    @media (prefers-reduced-motion: reduce) {*, *::before, *::after {scroll-behavior: auto !important; animation-duration: 0s !important; transition-duration: 0s !important;}}
  `}</style>;
}
