export function Bloom({className = ''}: {className?: string}) {
  const points = Array.from({length: 48}, (_, i) => {
    const angle = (i / 48) * Math.PI * 2;
    const radius = i % 2 ? 40 : 49;
    return `${50 + Math.cos(angle) * radius},${50 + Math.sin(angle) * radius}`;
  }).join(' ');
  return <svg viewBox="0 0 100 100" aria-hidden="true" className={`wild-bloom ${className}`}><polygon points={points} fill="currentColor" /></svg>;
}

export function Portrait({variant = 0}: {variant?: number}) {
  return <svg viewBox="0 0 180 200" aria-hidden="true" className={`wild-portrait portrait-${variant}`}>
    <path d="M15 200c1-48 24-75 75-75s74 27 75 75" className="portrait-shirt" />
    <path d="M69 117h42v39c-8 14-34 14-42 0z" className="portrait-skin" />
    <ellipse cx="90" cy="81" rx="39" ry="48" className="portrait-skin" />
    {variant === 1 ? <path d="M49 100V62c0-39 82-40 82 0v57l-16-15V68c-19 6-39-1-49-12v50z" className="portrait-hair" /> : variant === 2 ? <path d="M52 76c-13-35 5-54 23-48 10-20 44-12 46 8 23 1 24 28 8 45l-11-24-58 4z" className="portrait-hair" /> : <path d="M51 76c-7-35 8-57 40-57 31 0 49 22 37 62l-13-31c-14 12-34 12-50 5z" className="portrait-hair" />}
    <path d="M73 81h3m28 0h3" fill="none" className="portrait-ink" strokeWidth="5" strokeLinecap="round" />
    <path d="M79 106q11 9 22 0" fill="none" className="portrait-ink" strokeWidth="2.5" strokeLinecap="round" />
    {variant === 0 && <><rect x="62" y="70" width="24" height="22" rx="7" fill="none" className="portrait-ink" strokeWidth="2" /><rect x="96" y="70" width="24" height="22" rx="7" fill="none" className="portrait-ink" strokeWidth="2" /><path d="M86 77h10" className="portrait-ink" strokeWidth="2" /></>}
    <path d="M38 195v-21m104 21v-21" fill="none" className="portrait-seam" strokeWidth="2" />
  </svg>;
}

export function ProjectArt({reading = false}: {reading?: boolean}) {
  return reading ? <svg viewBox="0 0 400 250" aria-hidden="true" className="project-art">
    <ellipse cx="201" cy="225" rx="121" ry="11" className="art-shadow" />
    <g transform="translate(107 30) rotate(-11 90 95)"><rect width="165" height="193" rx="4" className="art-book" /><path d="M16 0v193" className="art-book-spine" strokeWidth="2" /><path d="M45 55h91M45 68h63M45 144h91M45 157h60" className="art-book-lines" strokeWidth="3" /><circle cx="91" cy="107" r="23" fill="none" className="art-book-lines" strokeWidth="2" /><path d="M68 107h46m-23-23v46" className="art-book-lines" strokeWidth="2" /></g>
    <path d="M300 47l8 15 17 3-12 12 1 17-14-8-15 7 3-17-11-13 17-2z" className="art-star" />
  </svg> : <svg viewBox="0 0 400 250" aria-hidden="true" className="project-art">
    <g className="art-browser"><rect x="43" y="38" width="313" height="188" rx="10" fill="none" stroke="currentColor" strokeWidth="2" /><path d="M43 64h313" fill="none" stroke="currentColor" strokeWidth="2" /><circle cx="58" cy="52" r="3" fill="currentColor" /><circle cx="69" cy="52" r="3" fill="currentColor" /><circle cx="80" cy="52" r="3" fill="currentColor" /></g>
    <path d="M94 96l26 90 39-90 38 90 27-90" fill="none" stroke="currentColor" strokeWidth="17" strokeLinejoin="round" />
    <path d="M263 109h51m-51 15h37m-37 35h51m-51 15h26" fill="none" stroke="currentColor" strokeWidth="3" />
    <circle cx="327" cy="205" r="30" className="art-browser-sticker" /><path d="M314 205h26m-12-12 12 12-12 12" className="art-sticker-ink" fill="none" strokeWidth="3" />
  </svg>;
}

export function OrbitArt() {
  return <svg viewBox="0 0 100 100" preserveAspectRatio="none" className="mos-graph-lines" aria-hidden="true">
    <g className="orbit-guides"><ellipse cx="50" cy="47" rx="40" ry="40" /><ellipse cx="50" cy="47" rx="27" ry="27" /><ellipse cx="50" cy="47" rx="13" ry="13" /></g>
    <g className="orbit-links"><path d="M50 43Q25 45 21 17M50 43Q72 49 79 27M50 43Q25 48 20 72M50 43Q68 55 77 77M21 17Q64 5 79 27M20 72Q50 94 77 77" /></g>
    <g className="orbit-dots"><circle cx="14" cy="35" r=".6" /><circle cx="80" cy="54" r=".7" /><circle cx="44" cy="90" r=".6" /><circle cx="55" cy="14" r=".8" /></g>
  </svg>;
}
