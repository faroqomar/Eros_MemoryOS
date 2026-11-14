'use client';

import {useEffect, useRef, useState, type CSSProperties} from 'react';
import {flushSync} from 'react-dom';
import {Bloom, Portrait, ProjectArt, OrbitArt} from './art';
import {Theme} from '@astryxdesign/core/theme';
import {Layout, LayoutHeader, LayoutContent, LayoutFooter, VStack, HStack} from '@astryxdesign/core/Layout';
import {Text, Heading} from '@astryxdesign/core/Text';
import {Button} from '@astryxdesign/core/Button';
import {IconButton} from '@astryxdesign/core/IconButton';
import {Icon} from '@astryxdesign/core/Icon';
import {TextInput} from '@astryxdesign/core/TextInput';
import {TextArea} from '@astryxdesign/core/TextArea';
import {BottomSheet} from '@astryxdesign/core/BottomSheet';
import {Switch} from '@astryxdesign/core/Switch';
import {Brain, UserRound, Folder, Cake, Settings, Mic, Plus, ArrowUp, ArrowLeft, ArrowRight, ChevronRight, Search, X, FileText, Check, Square, List, Network, Paperclip, MessageCircle, Menu, ArrowUpRight} from 'lucide-react';
import type {LucideIcon} from 'lucide-react';
import {memoryosTheme as theme} from '../theme/built/memoryos';
import '../theme/built/memoryos.css';
import {copy, people, projects, sources, type Copy, type Page, type Detail} from './data';
import {Styles} from './styles';


const dimensions = {
  '--memoryos-width': '86rem',
  '--memoryos-record-size': '8.5rem',
  '--memoryos-touch': '2.75rem',
  '--memoryos-line': '.0625rem',
} as CSSProperties;

const nav: {id: Page; label: Copy; icon: LucideIcon}[] = [
  {id:'capture',label:copy('Capture','التقاط'),icon:Mic},
  {id:'people',label:copy('People','الأشخاص'),icon:UserRound},
  {id:'projects',label:copy('Projects','المشاريع'),icon:Folder},
  {id:'birthdays',label:copy('Birthdays','الميلاد'),icon:Cake},
  {id:'brainmap',label:copy('BrainMap','الخريطة'),icon:Brain},
];
type Note = {id: string; text: string; voice: boolean};

export default function Page() {
  const [language, setLanguage] = useState<'en' | 'ar'>('en');
  const [page, setPage] = useState<Page>('capture');
  const [detail, setDetail] = useState<Detail>(null);
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

  function changeView(action: () => void) {
    if (typeof document.startViewTransition === 'function' && !matchMedia('(prefers-reduced-motion: reduce)').matches) {
      document.startViewTransition(() => flushSync(action));
    } else action();
  }
  function navigate(next: Page) {
    changeView(() => {
    setPage(next); setDetail(null); setTrail([]);
    setQuery(''); setSearchOpen(false); setSelectedNode(null); setQuestionOpen(false);
    });
  }
  function open(next: NonNullable<Detail>) {
    changeView(() => {setTrail(previous => [...previous, detail]); setDetail(next); setQuestionOpen(false); setAnswer(answers[next.id] || '');});
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
  function back() {changeView(() => {setDetail(trail.at(-1) || null); setTrail(trail.slice(0, -1)); setQuestionOpen(false);});}
  const p = people.find(value => value.id === detail?.id);
  const project = projects.find(value => value.id === detail?.id);
  const source = sources.find(value => value.id === detail?.id);
  const note = notes.find(value => value.id === detail?.id);
  const title = detail ? (detail.type === 'person' || detail.type === 'birthday' ? t(p!.name) : detail.type === 'project' ? t(project!.name) : detail.type === 'source' ? say('Original note', 'الملاحظة الأصلية') : say('Your capture', 'ملاحظتك')) : page === 'capture' ? say('Capture','التقاط') : page === 'settings' ? say('Settings', 'الإعدادات') : t(nav.find(item => item.id === page)!.label);
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
      <HStack gap={4}><VStack className={`wild-detail-portrait person-${p!.id}`}><Portrait variant={people.findIndex(value=>value.id===p!.id)} /></VStack><Text color="secondary">{t(p!.about)}</Text></HStack>
      <VStack><Text className="mos-section-label" color="secondary">{say('Birthday', 'عيد الميلاد')}</Text><Row label={t(p!.birthday)} icon={Cake} onClick={() => open({type: 'birthday', id: p!.id})} /></VStack>
      <VStack><Text className="mos-section-label" color="secondary">{say('Connected project', 'المشروع المرتبط')}</Text><Row label={t(projects.find(item => item.id === p!.project)!.name)} icon={Folder} onClick={() => open({type: 'project', id: p!.project})} /></VStack>
      <VStack gap={3}><Heading level={2} className="mos-section-heading">{say('Last conversation', 'آخر حديث')}</Heading><Text>{t(p!.context)}</Text><SourceLink id={p!.source} /></VStack>
      {answers[p!.id] && <VStack gap={2}><Text color="secondary" type="supporting">{say('Your demo answer', 'إجابتك التجريبية')}</Text><Text dir="auto">{answers[p!.id]}</Text></VStack>}
      <VStack gap={4}>{!questionOpen ? <Button label={say('Add something about this person', 'أضف شي عن هذا الشخص')} variant="ghost" icon={<Icon icon={Plus} size="sm" />} className="mos-source" onClick={() => setQuestionOpen(true)} /> : <><TextArea label={say('What would you like to remember about them?', 'شنو تحب تتذكر عن هذا الشخص؟')} value={answer} onChange={setAnswer} rows={3} /><Button label={say('Keep in this demo', 'حفظ بالعرض التجريبي')} isDisabled={!answer.trim()} onClick={() => {setAnswers(old => ({...old, [p!.id]: answer.trim()})); setQuestionOpen(false); setNotice(say('Demo answer added.', 'انضافت الإجابة التجريبية.'));}} /></>}</VStack>
    </VStack>;
    if (detail?.type === 'project') return <VStack gap={8} className="mos-detail"><VStack className={`wild-project-art ${project!.id==='reading'?'art-reading':'art-website'}`}><ProjectArt reading={project!.id==='reading'}/></VStack><Text color="secondary">{t(project!.context)}</Text><VStack gap={3}><Heading level={2} className="mos-section-heading">{say('Current thought', 'الفكرة الحالية')}</Heading><Text>{t(project!.plan)}</Text></VStack><VStack gap={3}><Text type="supporting" color="secondary">{say('An idea, still tentative', 'فكرة، بعد مو قرار')}</Text><Text className="mos-quote">{t(project!.idea)}</Text></VStack><VStack><Text className="mos-section-label" color="secondary">{say('People', 'الأشخاص')}</Text><Row label={t(people.find(item => item.id === project!.person)!.name)} icon={UserRound} onClick={() => open({type: 'person', id: project!.person})} /></VStack><VStack gap={2}><Heading level={2} className="mos-section-heading">{say('Where this came from', 'منين إجت الفكرة')}</Heading><SourceLink id={project!.source} /></VStack></VStack>;
    if (detail?.type === 'birthday') return <VStack gap={8} className="mos-detail"><HStack gap={5}><VStack className="mos-date mos-date-large"><Text type="supporting">{t(p!.month)}</Text><Text className="mos-date-day">{p!.day || '—'}</Text></VStack><VStack gap={1}><Text type="large">{t(p!.birthday)}</Text><Text color="secondary">{say('Birthday', 'عيد الميلاد')}</Text></VStack></HStack>{p!.day ? <><Switch label={say('Preview a reminder', 'معاينة تذكير')} value={!!reminders[p!.id]} onChange={value => setReminders(old => ({...old, [p!.id]: value}))} />{reminders[p!.id] && <VStack gap={3} className="mos-reminder"><Text>{say('On the day, at 9:00 AM', 'بنفس اليوم، الساعة ٩ صباحاً')}</Text><Text color="secondary">{say('A small reminder to wish them a happy birthday.', 'تذكير بسيط حتى تعايده بعيد ميلاده.')}</Text><Text type="supporting" color="secondary">{say('Preview only. No notification is scheduled.', 'معاينة فقط. ما راح ينرسل إشعار.')}</Text></VStack>}<SourceLink id={p!.source} /></> : <Text color="secondary">{say('No date in the sample notes yet.', 'بعد ماكو تاريخ بالملاحظات النموذجية.')}</Text>}</VStack>;
    if (page === 'capture') return <VStack className="mos-capture" gap={6}>
      <VStack className="wild-home-layout" gap={6}>
        <VStack className="wild-hero" gap={0}>
          <HStack className="wild-hero-top"><Text className="wild-kicker">{say('A LITTLE ROOM FOR EVERYTHING', 'مساحة لكل اللي ببالك')}</Text><Text className="wild-serial">01—∞</Text></HStack>
          <Heading level={2} className="wild-hero-title"><Text type="inherit">{say('Let it', 'طلّع اللي')}</Text><Text type="inherit" className="wild-italic">{say('out.', 'ببالك.')}</Text></Heading>
          <Text className="wild-hero-copy">{recording ? say('Keep going. This is your space.', 'كمّل. هاي مساحتك.') : say('A thought. A story.\nWhatever’s on your mind.', 'فكرة. سالفة.\nأي شي ببالك.')}</Text>
          <VStack className="wild-record-wrap"><Bloom className={recording ? 'is-recording' : ''} /><IconButton className="mos-record" label={recording ? say('Stop demo recording', 'إيقاف التسجيل التجريبي') : say('Start demo recording', 'بدء تسجيل تجريبي')} icon={<Icon icon={recording ? Square : Mic} className="mos-mic" />} onClick={toggleRecording} /><Text className="wild-record-caption">{recording ? `${Math.floor(elapsed / 60).toString().padStart(2,'0')}:${(elapsed % 60).toString().padStart(2,'0')}` : say('TAP TO TALK', 'اضغط واحچي')}</Text></VStack>
          {recording && <HStack className="wild-wave" gap={1}>{Array.from({length:13},(_,i)=><Text key={i} className="wave-bar" aria-hidden="true" style={{animationDelay:`${i*-.09}s`}}> </Text>)}<Text className="wild-demo-voice">{say('Demo only · Microphone off', 'عرض تجريبي · الميكروفون مغلق')}</Text></HStack>}
          <svg className="wild-scribble" viewBox="0 0 120 100" aria-hidden="true"><path d="M18 18c64-19 91 15 47 40-42 25-70-11-33-20 37-8 74 8 60 48m0 0-16-13m16 13 8-20" fill="none" stroke="currentColor" strokeWidth="2" /></svg>
        </VStack>
        <VStack className="wild-threads" gap={4}>
          <HStack className="mos-between"><Text className="wild-kicker">{notes.length ? say('FRESH OFF YOUR MIND', 'توه من بالك') : say('PICK UP A THREAD', 'كمّل من هنا')}</Text><Text className="wild-tiny-number">{String(notes.length || 2).padStart(2,'0')}</Text></HStack>
          <VStack className="wild-note-rail" gap={4}>
            {notes.length ? notes.slice(0,3).map((item,i)=><VStack as="button" className={`wild-note-card note-tone-${i%2}`} key={item.id} onClick={()=>open({type:'note',id:item.id})}><HStack className="mos-between"><Text className="wild-kicker">{item.voice?say('VOICE NOTE','ملاحظة صوتية'):say('JUST NOW','الآن')}</Text><Icon icon={ArrowUpRight}/></HStack><Text className="wild-note-text" dir="auto">{item.text}</Text><Text className="wild-note-bottom">{say('Open your capture','افتح ملاحظتك')}</Text></VStack>) : sources.slice(0,2).map((item,i)=><VStack as="button" className={`wild-note-card note-tone-${i}`} key={item.id} onClick={()=>open({type:'source',id:item.id})}><HStack className="mos-between"><Text className="wild-kicker">{i?say('WITH SARA','ويا سارة'):say('WITH ALI','ويا علي')}</Text><Icon icon={ArrowUpRight}/></HStack><Text className="wild-note-text">{i?say('One book.\nOne good thought.','كتاب واحد.\nوفكرة حلوة.'):say('What if the\nwebsite felt simpler?','لو نخلّي\nالموقع أبسط؟')}</Text><Text className="wild-note-bottom">{t(item.date)}</Text></VStack>)}
          </VStack>
        </VStack>
      </VStack>
    </VStack>;
    if (page === 'people') {
      const items=people.filter(item=>matches(t(item.name)+t(item.context)));
      return <VStack className="wild-people-screen" gap={6}><HStack className="wild-editorial-intro"><Heading level={2}>{say('The main','الشخصيات')}<Text type="inherit" className="wild-italic">{say('characters.','الأساسية.')}</Text></Heading><Text className="wild-outline-count">03</Text></HStack><VStack className="wild-people-grid" gap={4}>{items.length?items.map(item=><VStack as="button" className={`wild-person-card person-${item.id}`} key={item.id} onClick={()=>open({type:'person',id:item.id})}><HStack className="wild-person-top"><Text className="wild-kicker">{item.id==='ali'?say('DESIGN & POSSIBILITIES','تصميم وأفكار'):item.id==='sara'?say('BOOKS & LITTLE THINGS','كتب وتفاصيل'):say('IDEAS IN PROGRESS','أفكار تتطور')}</Text><Icon icon={ArrowUpRight}/></HStack><VStack className="wild-person-art"><Portrait variant={people.indexOf(item)}/><Text className="wild-person-initial">{item.initials}</Text></VStack><VStack gap={2} className="wild-person-caption"><Text className="wild-person-name">{t(item.name)}</Text><Text className="wild-person-context">{t(item.context)}</Text></VStack></VStack>):<Empty/>}</VStack><Text color="secondary" className="wild-footnote">{say('The people who make your world yours.','الناس اللي يخلّون عالمك إلك.')}</Text></VStack>;
    }
    if (page === 'projects') {
      const items=projects.filter(item=>matches(t(item.name)+t(item.context)));
      return <VStack className="wild-projects-screen" gap={6}><HStack className="wild-editorial-intro"><Heading level={2}>{say('Good things','الأشياء الحلوة')}<Text type="inherit" className="wild-italic">{say('start small.','تبدأ بفكرة.')}</Text></Heading><Text className="wild-mini-stamp">{say('WORK\nIN PROGRESS','بعدها\nبالبداية')}</Text></HStack><VStack className="wild-project-grid" gap={6}>{items.length?items.map(item=><VStack as="button" className={`wild-project-card project-${item.id}`} key={item.id} onClick={()=>open({type:'project',id:item.id})}><VStack className={`wild-project-art ${item.id==='reading'?'art-reading':'art-website'}`}><HStack className="wild-project-art-label"><Text className="wild-kicker">{item.id==='reading'?'02 / NOTES & MARGINS':'01 / A FRESH START'}</Text><Icon icon={ArrowUpRight}/></HStack><ProjectArt reading={item.id==='reading'}/></VStack><HStack className="wild-project-caption"><VStack gap={1}><Text className="wild-project-name">{t(item.name)}</Text><Text color="secondary">{t(item.context)}</Text></VStack><Text className="wild-project-number">{String(item.count).padStart(2,'0')}<Text type="inherit">{say('notes','ملاحظات')}</Text></Text></HStack></VStack>):<Empty/>}</VStack></VStack>;
    }
    if (page === 'birthdays') return <VStack className="wild-birthdays-screen" gap={6}>
      <VStack as="button" className="wild-birthday-poster" onClick={()=>open({type:'birthday',id:'ali'})}><HStack className="mos-between"><Text className="wild-kicker">{say('THE NEXT GOOD DAY','اليوم الحلو الجاي')}</Text><Icon icon={ArrowUpRight}/></HStack><Text className="wild-birthday-number">15</Text><Text className="wild-birthday-month">{say('November','تشرين الثاني')}</Text><HStack className="wild-birthday-person"><VStack className="wild-birthday-avatar"><Portrait variant={0}/></VStack><VStack gap={1}><Text>{say('Ali’s day.','يوم علي.')}</Text><Text className="wild-italic">{say('Make it a good one.','خلّيه يوم حلو.')}</Text></VStack></HStack><Bloom className="birthday-bloom"/><Text className="wild-birthday-spark">✳</Text></VStack>
      <VStack gap={3}><Text className="wild-kicker">{say('A LITTLE FURTHER AHEAD','وبعدين عدنا')}</Text>{people.filter(item=>item.day&&item.id!=='ali').map(item=><HStack as="button" className="wild-next-birthday" key={item.id} onClick={()=>open({type:'birthday',id:item.id})}><Text className="wild-next-day">{item.day}</Text><VStack gap={1}><Text className="wild-person-name">{t(item.name)}</Text><Text color="secondary">{t(item.birthday)}</Text></VStack><Icon icon={ArrowUpRight}/></HStack>)}</VStack><Text className="wild-footnote" color="secondary">{say('A date is a good reason to reach out.','التاريخ الحلو، فرصة نتذكر بيها أحبابنا.')}</Text>
    </VStack>;
    if (page === 'brainmap') {
      const nodes=[{id:'you',label:say('You','أنت'),icon:UserRound,x:50,y:43},{id:'ali',label:say('Ali','علي'),icon:UserRound,x:21,y:17},{id:'website',label:t(projects[0].name),icon:Folder,x:79,y:27},{id:'sara',label:say('Sara','سارة'),icon:UserRound,x:20,y:72},{id:'reading',label:t(projects[1].name),icon:Folder,x:77,y:77}];
      const node=nodes.find(item=>item.id===selectedNode);
      return <VStack className="mos-map-screen" gap={5}><HStack className="mos-map-tools"><Heading level={2}>{say('Everything','كل شي')}<Text type="inherit" className="wild-italic">{say('is connected.','مرتبط.')}</Text></Heading><IconButton label={graphList?say('Show map','عرض الخريطة'):say('Show as a list','عرض كقائمة')} className="wild-map-toggle" variant="ghost" icon={<Icon icon={graphList?Network:List}/>} onClick={()=>setGraphList(!graphList)}/></HStack>{graphList?<VStack gap={0} className="wild-map-list">{nodes.filter(item=>item.id!=='you').map(item=><Row key={item.id} label={item.label} sub={say('Connected through a sample note','مرتبط من خلال ملاحظة نموذجية')} icon={item.icon} onClick={()=>setSelectedNode(item.id)}/>)}</VStack>:<VStack className="mos-graph"><OrbitArt/>{nodes.map(item=><VStack as="button" key={item.id} className={`mos-node node-${item.id} ${item.id==='you'?'mos-node-you':''}`} style={{insetInlineStart:`${item.x}%`,top:`${item.y}%`}} onClick={()=>setSelectedNode(item.id)} aria-label={item.label} aria-pressed={item.id===selectedNode}><VStack className="mos-node-symbol">{item.id==='you'&&<Bloom/>}<Icon icon={item.icon} size="lg"/></VStack><Text className="mos-node-name">{item.label}</Text></VStack>)}</VStack>}{node&&<VStack className="mos-node-detail" gap={3}><HStack className="mos-between"><Text className="wild-person-name">{node.label}</Text><IconButton label={say('Close connection','إغلاق الرابط')} icon={<Icon icon={X}/>} variant="ghost" onClick={()=>setSelectedNode(null)}/></HStack><Text>{node.id==='you'?say('Your notes are the threads between these people and projects.','ملاحظاتك هي الخيوط بين هالأشخاص والمشاريع.'):say('Follow this thread back to the original note.','اتبع هذا الخيط للملاحظة الأصلية.')}</Text>{node.id!=='you'&&<Button label={say('Open details','فتح التفاصيل')} className="wild-solid-button" onClick={()=>open({type:people.some(item=>item.id===node.id)?'person':'project',id:node.id})} endContent={<Icon icon={ArrowUpRight}/>}/>}</VStack>}<Text className="mos-map-caption">{say('Tap a connection. Follow the thread.','اضغط على رابط. واتبع الخيط.')}</Text></VStack>;
    }
    return <VStack className="mos-detail wild-settings" gap={8}><Bloom className="settings-bloom"/><Heading level={2} className="wild-settings-title">{say('Your world.','عالمك.')}<Text type="inherit" className="wild-italic">{say('Your way.','بطريقتك.')}</Text></Heading><VStack gap={4}><Text className="wild-kicker">{say('PICK YOUR LANGUAGE','اختار لغتك')}</Text><HStack gap={3}><Button label="English" variant={ar?'secondary':'primary'} className="wild-language-choice" onClick={()=>setLanguage('en')} aria-pressed={!ar}/><Button label="العربية" variant={ar?'primary':'secondary'} className="wild-language-choice" onClick={()=>setLanguage('ar')} aria-pressed={ar}/></HStack></VStack><Text color="secondary">{say('A playground for your memories. All people and notes here are fictional. Changes reset on reload.','مساحة لتجربة ذكرياتك. الأشخاص والملاحظات هنا خيالية والتغييرات تنمسح لما تعيد تحميل الصفحة.')}</Text><Text type="supporting" color="secondary">{say('Recording and reminders are design previews.','التسجيل والتذكيرات للمعاينة التصميمية.')}</Text></VStack>;
  }

  return <Theme theme={theme} mode="light"><Styles/><VStack className={`mos-app route-${page} ${detail?'has-detail':''}`} gap={0} style={dimensions} dir={ar?'rtl':'ltr'}>
    <HStack className="mos-topbar"><HStack className="wild-brand" gap={2}><Bloom/><Text>memoryos</Text></HStack><Text className="wild-edition">{say('A PERSONAL UNIVERSE / VOL. 02','عالمك الشخصي / النسخة ٠٢')}</Text><HStack gap={2}><Button className="wild-top-language" variant="ghost" label={ar?'English':'العربية'} onClick={()=>setLanguage(ar?'en':'ar')}/><IconButton label={say('Settings','الإعدادات')} variant="ghost" icon={<Icon icon={Settings}/>} onClick={()=>navigate('settings')}/></HStack></HStack>
    <HStack className="mos-workspace" gap={0}>
      <VStack as="nav" className="mos-dock" aria-label={say('Main navigation','التنقل الرئيسي')} gap={2}>{nav.map(item=><Button label={t(item.label)} key={item.id} variant="ghost" className="mos-dock-item" aria-current={page===item.id?'page':undefined} onClick={()=>navigate(item.id)}><VStack className="wild-dock-content" gap={1}><Icon icon={item.icon} size="lg"/><Text type="inherit">{t(item.label)}</Text></VStack></Button>)}<VStack className="wild-nav-foot" gap={3}><Bloom/><Text>{say('Everything you are.\nA little more connected.','كل اللي أنت عليه.\nأقرب لبعضه.')}</Text><Text className="wild-kicker">{say('FICTIONAL SAMPLE DATA','بيانات خيالية للعرض')}</Text></VStack></VStack>
      <Layout height="fill" padding={0} className="mos-shell"
        header={<LayoutHeader className={`mos-header ${page==='capture'&&!detail?'mos-header-home':''}`}><HStack className="mos-between" gap={3}><HStack gap={3}>{detail&&<IconButton variant="ghost" label={say('Back','رجوع')} icon={<Icon icon={ar?ArrowRight:ArrowLeft}/>} onClick={back}/>}<VStack gap={1}><Text className="wild-kicker">{detail?say('FOLLOW THE THREAD','اتبع الخيط'):page==='capture'?say('YOUR SPACE. NO FILTER.','مساحتك. على راحتك.'):say('YOUR PERSONAL UNIVERSE','عالمك الشخصي')}</Text><Heading level={1} className="mos-title">{title}</Heading></VStack></HStack>{!detail&&(page==='people'||page==='projects')&&<IconButton label={say('Search','بحث')} variant="ghost" className="wild-search-toggle" icon={<Icon icon={Search}/>} onClick={()=>setSearchOpen(!searchOpen)}/>}</HStack>{searchOpen&&!detail&&<VStack className="mos-search"><TextInput type="search" label={say('Search memories','بحث بالذكريات')} isLabelHidden value={query} onChange={setQuery} placeholder={say('Find a name, a thought...','اسم، فكرة، أي شي...')} hasClear hasAutoFocus/></VStack>}</LayoutHeader>}
        content={<LayoutContent className="mos-content"><VStack as="main" className="mos-main" gap={0} data-screen={page}>{content()}</VStack></LayoutContent>}
        footer={!detail&&page==='capture'?<LayoutFooter className="mos-footer"><HStack className="mos-composer" gap={2}><IconButton variant="ghost" label={say('Add a sample attachment','إضافة مرفق نموذجي')} icon={<Icon icon={Plus}/>} onClick={()=>setAttachmentOpen(true)}/><TextInput ref={composer} label={say('Write a thought','اكتب فكرة')} value={draft} onChange={setDraft} isLabelHidden placeholder={say('Or, put it into words...','أو اكتب اللي ببالك...')} onEnter={()=>submit()} enterKeyHint="send" containerClassName="mos-composer-field" controlClassName="mos-composer-control"/><IconButton label={say('Save thought','حفظ الفكرة')} variant="primary" className="mos-send" icon={<Icon icon={ArrowUp}/>} isDisabled={!draft.trim()} onClick={()=>submit()}/></HStack></LayoutFooter>:undefined}
      />
    </HStack>
    {notice&&<VStack role="status" className="mos-notice"><HStack gap={2}><Icon icon={Check} size="sm"/><Text>{notice}</Text></HStack></VStack>}
    <BottomSheet label={say('Sample attachments','مرفقات نموذجية')} isOpen={attachmentOpen} onOpenChange={setAttachmentOpen} className="mos-attachment-sheet" style={dimensions}><VStack gap={5}><HStack className="mos-between"><Heading level={2} className="mos-section-heading">{say('Add a little context.','أضف شوية تفاصيل.')}</Heading><IconButton label={say('Close attachments','إغلاق المرفقات')} variant="ghost" icon={<Icon icon={X}/>} onClick={()=>setAttachmentOpen(false)}/></HStack><Text color="secondary">{say('Try a fictional note. No files are imported.','جرّب ملاحظة خيالية. ما راح نستورد ملفات.')}</Text>{sources.map(item=><Row key={item.id} label={t(item.title)} sub={t(item.date)} icon={Paperclip} onClick={()=>{submit(t(item.text));setAttachmentOpen(false)}}/>)}</VStack></BottomSheet>
  </VStack></Theme>;
}
