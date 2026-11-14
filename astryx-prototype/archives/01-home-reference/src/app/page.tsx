'use client';

import {useEffect, useRef, useState, type CSSProperties} from 'react';
import {Theme} from '@astryxdesign/core/theme';
import {Layout, LayoutHeader, LayoutContent, LayoutFooter, VStack, HStack} from '@astryxdesign/core/Layout';
import {Text, Heading} from '@astryxdesign/core/Text';
import {Button} from '@astryxdesign/core/Button';
import {IconButton} from '@astryxdesign/core/IconButton';
import {Icon} from '@astryxdesign/core/Icon';
import {TextInput} from '@astryxdesign/core/TextInput';
import {TextArea} from '@astryxdesign/core/TextArea';
import {Drawer} from '@astryxdesign/core/Drawer';
import {BottomSheet} from '@astryxdesign/core/BottomSheet';
import {Switch} from '@astryxdesign/core/Switch';
import {Brain, UserRound, Folder, Cake, Settings, Mic, Plus, ArrowUp, ArrowLeft, ArrowRight, ChevronRight, Search, X, FileText, Check, Square, List, Network, Paperclip, MessageCircle, Menu} from 'lucide-react';
import type {LucideIcon} from 'lucide-react';
import {memoryosTheme as theme} from '../theme/built/memoryos';
import '../theme/built/memoryos.css';
import {copy, people, projects, sources, type Copy, type Page, type Detail} from './data';
import {Styles} from './styles';


const dimensions = {
  '--memoryos-width': '27rem',
  '--memoryos-record-size': '10rem',
  '--memoryos-touch': '2.75rem',
  '--memoryos-line': '.0625rem',
} as CSSProperties;

const nav: {id: Page; label: Copy; icon: LucideIcon}[] = [
  {id: 'capture', label: copy('Capture', 'التقاط'), icon: Mic},
  {id: 'brainmap', label: copy('BrainMap', 'خريطة الذاكرة'), icon: Brain},
  {id: 'people', label: copy('People', 'الأشخاص'), icon: UserRound},
  {id: 'projects', label: copy('Projects', 'المشاريع'), icon: Folder},
  {id: 'birthdays', label: copy('Birthdays', 'أعياد الميلاد'), icon: Cake},
];
type Note = {id: string; text: string; voice: boolean};

export default function Page() {
  const [language, setLanguage] = useState<'en' | 'ar'>('en');
  const [page, setPage] = useState<Page>('capture');
  const [detail, setDetail] = useState<Detail>(null);
  const [menuOpen, setMenuOpen] = useState(false);
  const [attachmentOpen, setAttachmentOpen] = useState(false);
  const [searchOpen, setSearchOpen] = useState(false);
  const [query, setQuery] = useState('');
  const [draft, setDraft] = useState('');
  const [recording, setRecording] = useState(false);
  const [elapsed, setElapsed] = useState(0);
  const [notes, setNotes] = useState<Note[]>([]);
  const [notice, setNotice] = useState('');
  const [graphList, setGraphList] = useState(false);
  const [selectedNode, setSelectedNode] = useState<string | null>(null);
  const [reminders, setReminders] = useState<Record<string, boolean>>({});
  const [answer, setAnswer] = useState('');
  const [answers, setAnswers] = useState<Record<string, string>>({});
  const [questionOpen, setQuestionOpen] = useState(false);
  const [trail, setTrail] = useState<Detail[]>([]);
  const composer = useRef<HTMLInputElement>(null);
  const ar = language === 'ar';
  const t = (value: Copy) => value[language];
  const say = (en: string, arabic: string) => ar ? arabic : en;

  useEffect(() => {
    document.documentElement.lang = language;
    document.documentElement.dir = ar ? 'rtl' : 'ltr';
  }, [language, ar]);
  useEffect(() => {
    if (!recording) return;
    const timer = setInterval(() => setElapsed(value => value + 1), 1000);
    return () => clearInterval(timer);
  }, [recording]);
  useEffect(() => {
    if (!notice) return;
    const timer = setTimeout(() => setNotice(''), 4500);
    return () => clearTimeout(timer);
  }, [notice]);

  function navigate(next: Page) {
    setPage(next); setDetail(null); setTrail([]); setMenuOpen(false);
    setQuery(''); setSearchOpen(false); setSelectedNode(null); setQuestionOpen(false);
  }
  function open(next: NonNullable<Detail>) {
    setTrail(previous => [...previous, detail]); setDetail(next); setQuestionOpen(false); setAnswer(answers[next.id] || '');
  }
  function submit(text = draft, voice = false) {
    if (!text.trim()) return;
    setNotes(previous => [{id: String(Date.now()), text: text.trim(), voice}, ...previous]);
    setDraft(''); setNotice(say('Added to this demo.', 'انضاف للعرض التجريبي.'));
  }
  function toggleRecording() {
    if (recording) {
      submit(say('Ali and I talked about making the website simpler. I might prepare a draft next week.', 'حچيت ويا علي عن تبسيط الموقع. ممكن أحضّر مسودة الأسبوع الجاي.'), true);
      setRecording(false);
    } else { setElapsed(0); setRecording(true); }
  }
  function back() {setDetail(trail.at(-1) || null); setTrail(trail.slice(0, -1)); setQuestionOpen(false);}
  const p = people.find(value => value.id === detail?.id);
  const project = projects.find(value => value.id === detail?.id);
  const source = sources.find(value => value.id === detail?.id);
  const note = notes.find(value => value.id === detail?.id);
  const title = detail ? (detail.type === 'person' || detail.type === 'birthday' ? t(p!.name) : detail.type === 'project' ? t(project!.name) : detail.type === 'source' ? say('Original note', 'الملاحظة الأصلية') : say('Your capture', 'ملاحظتك')) : page === 'capture' ? 'MemoryOS' : page === 'settings' ? say('Settings', 'الإعدادات') : t(nav.find(item => item.id === page)!.label);
  const matches = (value: string) => value.toLocaleLowerCase().includes(query.toLocaleLowerCase().trim());

  function Row({label, sub, icon: Glyph, onClick, leading}: {label: string; sub?: string; icon?: LucideIcon; onClick: () => void; leading?: React.ReactNode}) {
    return <HStack as="button" className="mos-row" onClick={onClick} gap={4}>
      {leading || (Glyph && <Icon icon={Glyph} size="lg" className="mos-row-icon" />)}
      <VStack gap={1} className="mos-row-copy"><Text type="large" className="mos-row-label">{label}</Text>{sub && <Text color="secondary" className="mos-row-sub">{sub}</Text>}</VStack>
      <Icon icon={ar ? ArrowLeft : ChevronRight} size="sm" className="mos-chevron" />
    </HStack>;
  }
  function SourceLink({id}: {id: string}) {
    const item = sources.find(value => value.id === id)!;
    return <Button variant="ghost" label={say('View original note', 'عرض الملاحظة الأصلية')} icon={<Icon icon={FileText} size="sm" />} className="mos-source" onClick={() => open({type: 'source', id})}>{t(item.title)}</Button>;
  }
  function Empty() {return <VStack gap={2} className="mos-empty"><Text>{say('No matches', 'ماكو نتائج')}</Text><Text color="secondary">{say('Try another name or word.', 'جرّب اسم أو كلمة ثانية.')}</Text><Button variant="ghost" label={say('Clear search', 'مسح البحث')} onClick={() => setQuery('')} /></VStack>;}

  function content() {
    if (detail?.type === 'source') return <VStack gap={6} className="mos-detail"><Text color="secondary" type="supporting">{t(source!.date)}</Text><Heading level={2} className="mos-detail-heading">{t(source!.title)}</Heading><Text className="mos-original" dir="auto">{t(source!.text)}</Text><Text type="supporting" color="secondary">{say('Fictional source for this design study.', 'مصدر خيالي لهذا العرض التصميمي.')}</Text></VStack>;
    if (detail?.type === 'note') return <VStack gap={6} className="mos-detail"><Text type="supporting" color="secondary">{note?.voice ? say('Sample voice note', 'ملاحظة صوتية نموذجية') : say('Just now · Text note', 'الآن · ملاحظة نصية')}</Text><Text className="mos-original" dir="auto">{note?.text}</Text><Text type="supporting" color="secondary">{say('This capture stays in this demo until you reload.', 'تبقى هاي الملاحظة بالعرض لحد ما تعيد تحميل الصفحة.')}</Text></VStack>;
    if (detail?.type === 'person') return <VStack gap={8} className="mos-detail">
      <HStack gap={4}><VStack className="mos-avatar mos-avatar-large"><Icon icon={UserRound} size="lg" /></VStack><Text color="secondary">{t(p!.about)}</Text></HStack>
      <VStack><Text className="mos-section-label" color="secondary">{say('Birthday', 'عيد الميلاد')}</Text><Row label={t(p!.birthday)} icon={Cake} onClick={() => open({type: 'birthday', id: p!.id})} /></VStack>
      <VStack><Text className="mos-section-label" color="secondary">{say('Connected project', 'المشروع المرتبط')}</Text><Row label={t(projects.find(item => item.id === p!.project)!.name)} icon={Folder} onClick={() => open({type: 'project', id: p!.project})} /></VStack>
      <VStack gap={3}><Heading level={2} className="mos-section-heading">{say('Last conversation', 'آخر حديث')}</Heading><Text>{t(p!.context)}</Text><SourceLink id={p!.source} /></VStack>
      {answers[p!.id] && <VStack gap={2}><Text color="secondary" type="supporting">{say('Your demo answer', 'إجابتك التجريبية')}</Text><Text dir="auto">{answers[p!.id]}</Text></VStack>}
      <VStack gap={4}>{!questionOpen ? <Button label={say('Add something about this person', 'أضف شي عن هذا الشخص')} variant="ghost" icon={<Icon icon={Plus} size="sm" />} className="mos-source" onClick={() => setQuestionOpen(true)} /> : <><TextArea label={say('What would you like to remember about them?', 'شنو تحب تتذكر عن هذا الشخص؟')} value={answer} onChange={setAnswer} rows={3} /><Button label={say('Keep in this demo', 'حفظ بالعرض التجريبي')} isDisabled={!answer.trim()} onClick={() => {setAnswers(old => ({...old, [p!.id]: answer.trim()})); setQuestionOpen(false); setNotice(say('Demo answer added.', 'انضافت الإجابة التجريبية.'));}} /></>}</VStack>
    </VStack>;
    if (detail?.type === 'project') return <VStack gap={8} className="mos-detail"><Text color="secondary">{t(project!.context)}</Text><VStack gap={3}><Heading level={2} className="mos-section-heading">{say('Current thought', 'الفكرة الحالية')}</Heading><Text>{t(project!.plan)}</Text></VStack><VStack gap={3}><Text type="supporting" color="secondary">{say('An idea, still tentative', 'فكرة، بعد مو قرار')}</Text><Text className="mos-quote">{t(project!.idea)}</Text></VStack><VStack><Text className="mos-section-label" color="secondary">{say('People', 'الأشخاص')}</Text><Row label={t(people.find(item => item.id === project!.person)!.name)} icon={UserRound} onClick={() => open({type: 'person', id: project!.person})} /></VStack><VStack gap={2}><Heading level={2} className="mos-section-heading">{say('Where this came from', 'منين إجت الفكرة')}</Heading><SourceLink id={project!.source} /></VStack></VStack>;
    if (detail?.type === 'birthday') return <VStack gap={8} className="mos-detail"><HStack gap={5}><VStack className="mos-date mos-date-large"><Text type="supporting">{t(p!.month)}</Text><Text className="mos-date-day">{p!.day || '—'}</Text></VStack><VStack gap={1}><Text type="large">{t(p!.birthday)}</Text><Text color="secondary">{say('Birthday', 'عيد الميلاد')}</Text></VStack></HStack>{p!.day ? <><Switch label={say('Preview a reminder', 'معاينة تذكير')} value={!!reminders[p!.id]} onChange={value => setReminders(old => ({...old, [p!.id]: value}))} />{reminders[p!.id] && <VStack gap={3} className="mos-reminder"><Text>{say('On the day, at 9:00 AM', 'بنفس اليوم، الساعة ٩ صباحاً')}</Text><Text color="secondary">{say('A small reminder to wish them a happy birthday.', 'تذكير بسيط حتى تعايده بعيد ميلاده.')}</Text><Text type="supporting" color="secondary">{say('Preview only. No notification is scheduled.', 'معاينة فقط. ما راح ينرسل إشعار.')}</Text></VStack>}<SourceLink id={p!.source} /></> : <Text color="secondary">{say('No date in the sample notes yet.', 'بعد ماكو تاريخ بالملاحظات النموذجية.')}</Text>}</VStack>;
    if (page === 'capture') return <VStack className="mos-capture" gap={0}><VStack className="mos-record-area" gap={6}><IconButton className={`mos-record ${recording ? 'mos-is-recording' : ''}`} label={recording ? say('Stop demo recording', 'إيقاف التسجيل التجريبي') : say('Start demo recording', 'بدء تسجيل تجريبي')} icon={<Icon icon={recording ? Square : Mic} className="mos-mic" />} onClick={toggleRecording} /><Text className="mos-record-label">{recording ? say('Tap to stop', 'اضغط للإيقاف') : say('Tap to record', 'اضغط للتسجيل')}</Text>{recording && <VStack gap={2} className="mos-record-state"><Text className="mos-timer" aria-live="off">{`${Math.floor(elapsed / 60).toString().padStart(2, '0')}:${(elapsed % 60).toString().padStart(2, '0')}`}</Text><Text type="supporting" color="secondary">{say('Demo only · Microphone off', 'عرض تجريبي · الميكروفون مغلق')}</Text></VStack>}</VStack>{notes.length > 0 && <VStack className="mos-recent" gap={2}><Text type="supporting" color="secondary">{say('In this session', 'بهذه الجلسة')}</Text>{notes.slice(0, 2).map(item => <Row key={item.id} label={item.text} sub={item.voice ? say('Sample voice note', 'ملاحظة صوتية نموذجية') : say('Just now', 'الآن')} icon={item.voice ? Mic : FileText} onClick={() => open({type: 'note', id: item.id})} />)}</VStack>}</VStack>;
    if (page === 'people') {const items = people.filter(item => matches(t(item.name) + t(item.context))); return <VStack className="mos-list-screen" gap={0}><Text color="secondary" className="mos-intro">{say('The people in your memories.', 'الأشخاص بذكرياتك.')}</Text>{items.length ? items.map(item => <Row key={item.id} label={t(item.name)} sub={t(item.context)} leading={<VStack className="mos-avatar"><Icon icon={UserRound} size="lg" /></VStack>} onClick={() => open({type: 'person', id: item.id})} />) : <Empty />}</VStack>;}
    if (page === 'projects') {const items = projects.filter(item => matches(t(item.name) + t(item.context))); return <VStack className="mos-list-screen" gap={0}><Text color="secondary" className="mos-intro">{say('Ideas with somewhere to grow.', 'مكان للأفكار حتى تكبر.')}</Text>{items.length ? items.map(item => <Row key={item.id} label={t(item.name)} sub={t(item.context)} icon={Folder} onClick={() => open({type: 'project', id: item.id})} />) : <Empty />}</VStack>;}
    if (page === 'birthdays') return <VStack className="mos-list-screen" gap={0}><Text color="secondary" className="mos-intro">{say('Small dates worth remembering.', 'تواريخ بسيطة تستاهل نتذكرها.')}</Text>{people.filter(item => item.day).map(item => <Row key={item.id} label={t(item.name)} sub={t(item.birthday)} leading={<VStack className="mos-date"><Text type="supporting">{t(item.month)}</Text><Text className="mos-date-day">{item.day}</Text></VStack>} onClick={() => open({type: 'birthday', id: item.id})} />)}<Text color="secondary" type="supporting" className="mos-list-foot">{say('Open a birthday to preview its reminder.', 'افتح عيد ميلاد حتى تعاين التذكير.')}</Text></VStack>;
    if (page === 'brainmap') {
      const nodes = [{id: 'you', label: say('You', 'أنت'), icon: UserRound, x: 50, y: 43}, {id: 'ali', label: say('Ali', 'علي'), icon: UserRound, x: 21, y: 17}, {id: 'website', label: t(projects[0].name), icon: Folder, x: 79, y: 27}, {id: 'sara', label: say('Sara', 'سارة'), icon: UserRound, x: 20, y: 72}, {id: 'reading', label: t(projects[1].name), icon: Folder, x: 77, y: 77}];
      const node = nodes.find(item => item.id === selectedNode);
      return <VStack gap={5} className="mos-map-screen"><HStack className="mos-map-tools"><Text color="secondary">{say('A few things, connected.', 'أشياء بسيطة، مرتبطة.')}</Text><IconButton label={graphList ? say('Show map', 'عرض الخريطة') : say('Show as a list', 'عرض كقائمة')} variant="ghost" icon={<Icon icon={graphList ? Network : List} />} onClick={() => setGraphList(!graphList)} /></HStack>{graphList ? <VStack gap={0}>{nodes.filter(item => item.id !== 'you').map(item => <Row key={item.id} label={item.label} sub={say('Connected through a sample note', 'مرتبط من خلال ملاحظة نموذجية')} icon={item.icon} onClick={() => setSelectedNode(item.id)} />)}</VStack> : <VStack className="mos-graph"><svg viewBox="0 0 100 100" preserveAspectRatio="none" className="mos-graph-lines" aria-hidden="true"><path d="M50 43 L21 17 M50 43 L79 27 M50 43 L20 72 M50 43 L77 77 M21 17 L79 27 M20 72 L77 77" /></svg>{nodes.map(item => <VStack as="button" key={item.id} className={`mos-node ${item.id === 'you' ? 'mos-node-you' : ''}`} style={{insetInlineStart: `${item.x}%`, top: `${item.y}%`}} onClick={() => setSelectedNode(item.id)} aria-label={item.label} aria-pressed={item.id === selectedNode}><VStack className="mos-node-symbol"><Icon icon={item.icon} size="lg" /></VStack><Text className="mos-node-name">{item.label}</Text></VStack>)}</VStack>}{node && <VStack gap={4} className="mos-node-detail"><HStack className="mos-between"><Text weight="bold">{node.label}</Text><IconButton label={say('Close connection', 'إغلاق الرابط')} icon={<Icon icon={X} />} variant="ghost" onClick={() => setSelectedNode(null)} /></HStack><Text color="secondary">{node.id === 'you' ? say('Your notes connect these people and projects.', 'ملاحظاتك تربط هالأشخاص والمشاريع.') : say('Connected through the original note.', 'مرتبط من خلال الملاحظة الأصلية.')}</Text>{node.id !== 'you' && <Button label={say('Open details', 'فتح التفاصيل')} variant="ghost" className="mos-source" onClick={() => open({type: people.some(item => item.id === node.id) ? 'person' : 'project', id: node.id})} />}</VStack>}<Text type="supporting" color="secondary" className="mos-map-caption">{say('Sample connections · Tap to explore', 'روابط نموذجية · اضغط للاستكشاف')}</Text></VStack>;
    }
    return <VStack gap={8} className="mos-detail"><VStack gap={3}><Heading level={2} className="mos-section-heading">{say('Language', 'اللغة')}</Heading><HStack gap={3}><Button label="English" variant={ar ? 'secondary' : 'primary'} onClick={() => setLanguage('en')} aria-pressed={!ar} /><Button label="العربية" variant={ar ? 'primary' : 'secondary'} onClick={() => setLanguage('ar')} aria-pressed={ar} /></HStack></VStack><VStack gap={3}><Heading level={2} className="mos-section-heading">{say('About this design', 'عن هذا التصميم')}</Heading><Text color="secondary">{say('Fictional people and notes. Try the screens, capture a thought, and explore the connections.', 'أشخاص وملاحظات خيالية. جرّب الشاشات واكتب فكرة واستكشف الروابط.')}</Text><Text type="supporting" color="secondary">{say('Changes reset when you reload. Recording and reminders are previews.', 'التغييرات تنمسح لما تعيد تحميل الصفحة. التسجيل والتذكيرات للمعاينة.')}</Text></VStack></VStack>;
  }

  return <Theme theme={theme} mode="light"><Styles /><VStack className="mos-review" gap={0} style={dimensions}>
    <HStack as="aside" className="mos-review-bar"><Text type="supporting" color="secondary">{say('MemoryOS · Design prototype', 'MemoryOS · نموذج تصميم')}</Text><Button className="mos-language" variant="ghost" size="sm" label={ar ? 'English' : 'العربية'} onClick={() => setLanguage(ar ? 'en' : 'ar')} /></HStack>
    <VStack className="mos-phone" dir={ar ? 'rtl' : 'ltr'} gap={0}>
      <Layout height="fill" padding={0} className="mos-shell"
        header={<LayoutHeader className="mos-header"><HStack gap={3}><IconButton variant="ghost" className="mos-menu-button" label={detail ? say('Back', 'رجوع') : say('Open menu', 'فتح القائمة')} icon={<Icon icon={detail ? (ar ? ArrowRight : ArrowLeft) : Menu} size="lg" />} onClick={detail ? back : () => setMenuOpen(true)} /><Heading level={1} className="mos-title">{title}</Heading>{!detail && (page === 'people' || page === 'projects') && <IconButton label={say('Search', 'بحث')} variant="ghost" icon={<Icon icon={Search} />} onClick={() => setSearchOpen(!searchOpen)} />}</HStack>{searchOpen && !detail && <VStack className="mos-search"><TextInput type="search" label={say('Search memories', 'بحث بالذكريات')} isLabelHidden value={query} onChange={setQuery} placeholder={say('Search by name or word', 'ابحث باسم أو كلمة')} hasClear hasAutoFocus /></VStack>}</LayoutHeader>}
        content={<LayoutContent className={`mos-content ${page === 'capture' && !detail ? 'mos-content-capture' : ''}`}><VStack as="main" className="mos-main" gap={0}>{content()}</VStack></LayoutContent>}
        footer={!detail && page === 'capture' ? <LayoutFooter className="mos-footer"><HStack className="mos-composer" gap={1}><IconButton variant="ghost" label={say('Add a sample attachment', 'إضافة مرفق نموذجي')} icon={<Icon icon={Plus} size="lg" />} onClick={() => setAttachmentOpen(true)} /><TextInput ref={composer} label={say('Write a thought', 'اكتب فكرة')} value={draft} onChange={setDraft} isLabelHidden placeholder={say('Write anything...', 'اكتب أي شي...')} onEnter={() => submit()} enterKeyHint="send" containerClassName="mos-composer-field" controlClassName="mos-composer-control" /><IconButton label={say('Save thought', 'حفظ الفكرة')} variant="primary" className="mos-send" icon={<Icon icon={ArrowUp} />} isDisabled={!draft.trim()} onClick={() => submit()} /></HStack></LayoutFooter> : undefined}
      />
      {notice && <VStack role="status" className="mos-notice"><HStack gap={2}><Icon icon={Check} size="sm" /><Text type="supporting">{notice}</Text></HStack></VStack>}
    </VStack>
    <Text color="secondary" type="supporting" className="mos-review-caption">{say('Fictional sample data · Built with Astryx', 'بيانات خيالية · صُمّم باستخدام Astryx')}</Text>
    <Drawer label={say('MemoryOS menu', 'قائمة MemoryOS')} isOpen={menuOpen} onOpenChange={setMenuOpen} side="start" width="min(84vw, 22rem)" padding={0} className="mos-drawer" style={dimensions}>
      <VStack className="mos-drawer-inner" gap={0}><HStack className="mos-drawer-header"><Heading level={2} className="mos-title">MemoryOS</Heading><IconButton label={say('Close menu', 'إغلاق القائمة')} variant="ghost" icon={<Icon icon={X} size="lg" />} onClick={() => setMenuOpen(false)} /></HStack><VStack as="nav" aria-label={say('Main navigation', 'التنقل الرئيسي')} className="mos-nav" gap={2}>{nav.map(item => <Button key={item.id} label={t(item.label)} variant="ghost" className="mos-nav-item" icon={<Icon icon={item.icon} size="lg" />} onClick={() => navigate(item.id)} aria-current={page === item.id ? 'page' : undefined} />)}</VStack><VStack className="mos-nav-bottom"><Button label={say('Settings', 'الإعدادات')} variant="ghost" className="mos-nav-item" icon={<Icon icon={Settings} size="lg" />} onClick={() => navigate('settings')} /></VStack></VStack>
    </Drawer>
    <BottomSheet label={say('Sample attachments', 'مرفقات نموذجية')} isOpen={attachmentOpen} onOpenChange={setAttachmentOpen} className="mos-attachment-sheet" style={dimensions}><VStack gap={5}><HStack className="mos-between"><Heading level={2} className="mos-section-heading">{say('Try a sample attachment', 'جرّب مرفق نموذجي')}</Heading><IconButton label={say('Close attachments', 'إغلاق المرفقات')} variant="ghost" icon={<Icon icon={X} />} onClick={() => setAttachmentOpen(false)} /></HStack><Text color="secondary">{say('Choose a fictional note to see it in your captures.', 'اختار ملاحظة خيالية حتى تشوفها بالملاحظات.')}</Text>{sources.map(item => <Row key={item.id} label={t(item.title)} sub={t(item.date)} icon={Paperclip} onClick={() => {submit(t(item.text)); setAttachmentOpen(false);}} />)}</VStack></BottomSheet>
  </VStack></Theme>;
}
