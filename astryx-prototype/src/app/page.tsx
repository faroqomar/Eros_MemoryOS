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
import {BottomSheet} from '@astryxdesign/core/BottomSheet';
import {Switch} from '@astryxdesign/core/Switch';
import {Brain, UserRound, Folder, Cake, Settings, Mic, Plus, ArrowUp, ArrowLeft, ArrowRight, ChevronRight, Search, X, FileText, Check, Square, List, Network, Paperclip, MessageCircle, Menu, Circle, CalendarDays, ChevronLeft} from 'lucide-react';
import type {LucideIcon} from 'lucide-react';
import {memoryosTheme as theme} from '../theme/built/memoryos';
import '../theme/built/memoryos.css';
import {copy, people, projects, sources, type Copy, type Page, type Detail} from './data';
import {Styles} from './styles';


const dimensions = {
  '--memoryos-width': '76rem',
  '--memoryos-record-size': '10rem',
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
  const [appearance,setAppearance] = useState<'light'|'dark'>('light');
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
    setPage(next); setDetail(null); setTrail([]);
    setQuery(''); setSearchOpen(false); setSelectedNode(null); setQuestionOpen(false);
  }
  function open(next: NonNullable<Detail>) {
    setTrail(previous => [...previous, detail]); setDetail(next); setQuestionOpen(false); setAnswer(answers[next.id] || '');
  }
  function submit(text = draft, voice = false) {
    if (!text.trim()) return;
    setNotes(previous => [{id: String(Date.now()), text: text.trim(), voice}, ...previous]);
    setDraft(''); setNotice(say('Added to the preview.','انضافت للمعاينة.'));
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
  const title = detail ? (detail.type === 'person' || detail.type === 'birthday' ? t(p!.name) : detail.type === 'project' ? t(project!.name) : detail.type === 'source' ? say('Original note', 'الملاحظة الأصلية') : say('Your capture', 'ملاحظتك')) : page === 'capture' ? 'MemoryOS' : page === 'settings' ? say('Settings','الإعدادات') : page === 'birthdays' ? say('Birthdays','أعياد الميلاد') : page === 'brainmap' ? say('BrainMap','خريطة الذاكرة') : t(nav.find(item=>item.id===page)!.label);
  const matches = (value: string) => value.toLocaleLowerCase().includes(query.toLocaleLowerCase().trim());

  function Row({label, sub, icon: Glyph, onClick, leading}: {label: string; sub?: string; icon?: LucideIcon; onClick: () => void; leading?: React.ReactNode}) {
    return <HStack as="button" className="ios-row" onClick={onClick} gap={4}>
      {leading || (Glyph && <Icon icon={Glyph} size="lg" className="ios-row-icon" />)}
      <VStack gap={1} className="ios-row-copy"><Text type="large" className="ios-row-title">{label}</Text>{sub && <Text color="secondary" className="ios-row-sub">{sub}</Text>}</VStack>
      <Icon icon={ar ? ArrowLeft : ChevronRight} size="sm" className="ios-chevron" />
    </HStack>;
  }
  function SourceLink({id}: {id: string}) {
    const item = sources.find(value => value.id === id)!;
    return <Button variant="ghost" label={say('View original note', 'عرض الملاحظة الأصلية')} icon={<Icon icon={FileText} size="sm" />} className="ios-source" onClick={() => open({type: 'source', id})}>{t(item.title)}</Button>;
  }
  function Empty() {return <VStack gap={2} className="ios-empty"><Text>{say('No matches', 'ماكو نتائج')}</Text><Text color="secondary">{say('Try another name or word.', 'جرّب اسم أو كلمة ثانية.')}</Text><Button variant="ghost" label={say('Clear search', 'مسح البحث')} onClick={() => setQuery('')} /></VStack>;}

  function Initials({id,large=false}: {id:string;large?:boolean}) {
    const person=people.find(item=>item.id===id)!;
    return <VStack className={`ios-avatar ${large?'ios-avatar-large':''}`}><Text>{ar?t(person.name).split(' ').map(s=>s[0]).join(''):person.initials}</Text></VStack>;
  }
  function SearchField() {return <TextInput label={say('Search memories','بحث بالذكريات')} isLabelHidden type="search" value={query} onChange={setQuery} placeholder={say('Search','بحث')} startIcon={Search} hasClear containerClassName="ios-search" controlClassName="ios-search-control"/>;}
  function VoiceCard() {
    const heights=[10,18,30,15,40,58,25,48,70,34,56,78,40,60,26,44,64,30,48,18,32,14,8];
    return <VStack className={`ios-voice-card ${recording?'is-recording':''}`} gap={3}>
      <HStack className="ios-between"><HStack gap={2}><Icon icon={Mic} className="ios-record-icon"/><Text className="ios-voice-title">{say('Voice note','ملاحظة صوتية')}</Text></HStack><Text className="ios-small" color="secondary">{say('Preview','معاينة')}</Text></HStack>
      <svg viewBox="0 0 310 80" className="ios-waveform" aria-hidden="true">{heights.map((h,i)=><line key={i} x1={12+i*13} x2={12+i*13} y1={40-h/2} y2={40+h/2} style={{animationDelay:`${i*-.07}s`}}/>)}</svg>
      <IconButton className={`ios-record ${recording?'is-recording':''}`} label={recording?say('Stop demo recording','إيقاف التسجيل التجريبي'):say('Start demo recording','بدء تسجيل تجريبي')} icon={<Icon icon={recording?Square:Circle} className="ios-record-glyph"/>} onClick={toggleRecording}/>
      <Text className={recording?'ios-record-timer':'ios-record-caption'}>{recording?`${Math.floor(elapsed/60).toString().padStart(2,'0')}:${(elapsed%60).toString().padStart(2,'0')}`:say('Tap to record','اضغط للتسجيل')}</Text>
      {recording&&<Text className="ios-small" color="secondary">{say('Demo only · Microphone off','عرض تجريبي · الميكروفون مغلق')}</Text>}
    </VStack>;
  }
  function Composer() {return <HStack className="ios-composer" gap={1}><IconButton label={say('Add a sample attachment','إضافة مرفق نموذجي')} variant="ghost" icon={<Icon icon={Plus}/>} onClick={()=>setAttachmentOpen(true)}/><TextInput ref={composer} label={say('Write a thought','اكتب فكرة')} isLabelHidden value={draft} onChange={setDraft} placeholder={say('Write a note...','اكتب ملاحظة...')} onEnter={()=>submit()} enterKeyHint="send" containerClassName="ios-composer-field" controlClassName="ios-composer-control"/><IconButton label={say('Save thought','حفظ الفكرة')} className="ios-send" icon={<Icon icon={ArrowUp}/>} isDisabled={!draft.trim()} onClick={()=>submit()}/></HStack>;}
  function SectionLabel({children}: {children:React.ReactNode}) {return <Text className="ios-section-label" color="secondary">{children}</Text>;}
  function CalendarMark({id='ali',large=false}: {id?:string;large?:boolean}) {const person=people.find(item=>item.id===id)!;return <VStack className={`ios-calendar-mark ${large?'is-large':''}`}><Text>{t(person.month)}</Text><Text>{person.day||'—'}</Text></VStack>;}
  function content() {
    if(detail?.type==='source')return <VStack className="ios-note-detail" gap={5}><Text className="ios-small" color="secondary">{t(source!.date)}</Text><Heading level={2}>{t(source!.title)}</Heading><Text className="ios-original" dir="auto">{t(source!.text)}</Text><Text className="ios-small" color="secondary">{say('Fictional source for this design preview.','مصدر خيالي لهذا العرض التصميمي.')}</Text></VStack>;
    if(detail?.type==='note')return <VStack className="ios-note-detail" gap={5}><Text className="ios-small" color="secondary">{note?.voice?say('Sample voice note','ملاحظة صوتية نموذجية'):say('Just now · Text note','الآن · ملاحظة نصية')}</Text><Text className="ios-original" dir="auto">{note?.text}</Text><Text className="ios-small" color="secondary">{say('This note stays in the preview until you reload.','تبقى الملاحظة بالعرض لحد ما تعيد تحميل الصفحة.')}</Text></VStack>;
    if(detail?.type==='person')return <VStack className="ios-detail" gap={6}>
      <VStack className="ios-person-header" gap={3}><Initials id={p!.id} large/><Heading level={2}>{t(p!.name)}</Heading><Text color="secondary">{t(p!.about)}</Text></VStack>
      <VStack gap={2}><SectionLabel>{say('Details','التفاصيل')}</SectionLabel><VStack className="ios-group" gap={0}><Row label={say('Birthday','عيد الميلاد')} sub={t(p!.birthday)} icon={Cake} onClick={()=>open({type:'birthday',id:p!.id})}/><Row label={t(projects.find(item=>item.id===p!.project)!.name)} sub={say('Connected project','المشروع المرتبط')} icon={Folder} onClick={()=>open({type:'project',id:p!.project})}/></VStack></VStack>
      <VStack gap={2}><SectionLabel>{say('Recent conversation','آخر حديث')}</SectionLabel><VStack className="ios-group ios-group-content" gap={3}><Text>{t(p!.context)}</Text><SourceLink id={p!.source}/></VStack></VStack>
      {answers[p!.id]&&<VStack gap={2}><SectionLabel>{say('Your note','ملاحظتك')}</SectionLabel><VStack className="ios-group ios-group-content"><Text dir="auto">{answers[p!.id]}</Text></VStack></VStack>}
      {!questionOpen?<Button label={say('Add something about this person','أضف شي عن هذا الشخص')} className="ios-link-button" variant="ghost" icon={<Icon icon={Plus}/>} onClick={()=>setQuestionOpen(true)}/>:<VStack className="ios-group ios-group-content" gap={4}><TextArea label={say('What would you like to remember about them?','شنو تحب تتذكر عن هذا الشخص؟')} value={answer} onChange={setAnswer} rows={3}/><Button label={say('Save in preview','حفظ بالمعاينة')} isDisabled={!answer.trim()} onClick={()=>{setAnswers(old=>({...old,[p!.id]:answer.trim()}));setQuestionOpen(false);setNotice(say('Note added.','انضافت الملاحظة.'));}}/></VStack>}
    </VStack>;
    if(detail?.type==='project')return <VStack className="ios-detail" gap={6}><VStack className="ios-project-header" gap={3}><Icon icon={Folder} className="ios-folder-large"/><Heading level={2}>{t(project!.name)}</Heading><Text color="secondary">{t(project!.context)}</Text></VStack><VStack gap={2}><SectionLabel>{say('Current thought','الفكرة الحالية')}</SectionLabel><VStack className="ios-group ios-group-content"><Text>{t(project!.plan)}</Text></VStack></VStack><VStack gap={2}><SectionLabel>{say('Still an idea','بعدها فكرة')}</SectionLabel><VStack className="ios-group ios-group-content" gap={3}><Text>{t(project!.idea)}</Text><Text className="ios-small" color="secondary">{say('Tentative, not a confirmed plan.','فكرة محتملة، مو خطة مؤكدة.')}</Text></VStack></VStack><VStack gap={2}><SectionLabel>{say('People','الأشخاص')}</SectionLabel><VStack className="ios-group"><Row label={t(people.find(item=>item.id===project!.person)!.name)} leading={<Initials id={project!.person}/>} onClick={()=>open({type:'person',id:project!.person})}/></VStack></VStack><VStack gap={2}><SectionLabel>{say('Source','المصدر')}</SectionLabel><VStack className="ios-group ios-group-content"><SourceLink id={project!.source}/></VStack></VStack></VStack>;
    if(detail?.type==='birthday')return <VStack className="ios-detail" gap={6}><VStack className="ios-person-header" gap={3}><CalendarMark id={p!.id} large/><Heading level={2}>{t(p!.name)}</Heading><Text color="secondary">{t(p!.birthday)}</Text></VStack>{p!.day?<><VStack className="ios-group ios-group-content" gap={4}><Switch label={say('Preview a reminder','معاينة تذكير')} value={!!reminders[p!.id]} onChange={value=>setReminders(old=>({...old,[p!.id]:value}))}/>{reminders[p!.id]&&<VStack gap={2}><Text>{say('On the day, at 9:00 AM','بنفس اليوم، الساعة ٩ صباحاً')}</Text><Text className="ios-small" color="secondary">{say('Preview only. No notification is scheduled.','معاينة فقط. ما راح ينرسل إشعار.')}</Text></VStack>}</VStack><VStack className="ios-group ios-group-content"><SourceLink id={p!.source}/></VStack></>:<Text color="secondary">{say('A birthday has not been added to the sample notes.','بعد ما انضاف عيد ميلاد للملاحظات النموذجية.')}</Text>}</VStack>;
    if(page==='capture')return <VStack className="ios-home" gap={6}><VStack className="ios-capture-column" gap={4}><VoiceCard/><Composer/></VStack><VStack className="ios-recent-column" gap={2}><HStack className="ios-section-heading"><Heading level={2}>{say('Recent','الأخيرة')}</Heading><Text className="ios-small" color="secondary">{notes.length+sources.length}</Text></HStack><VStack className="ios-group" gap={0}>{notes.slice(0,3).map(item=><Row key={item.id} label={item.text} sub={item.voice?say('Sample voice note','ملاحظة صوتية نموذجية'):say('Just now','الآن')} icon={item.voice?Mic:FileText} onClick={()=>open({type:'note',id:item.id})}/>)}{sources.map(item=><Row key={item.id} label={t(item.title)} sub={t(item.date)} icon={FileText} onClick={()=>open({type:'source',id:item.id})}/>)}</VStack><Text className="ios-section-footnote" color="secondary">{say('Your ideas, with their original context.','أفكارك، ويا تفاصيلها الأصلية.')}</Text></VStack></VStack>;
    if(page==='people'){const items=people.filter(item=>matches(t(item.name)+t(item.context)));return <VStack gap={4}><Text className="ios-section-footnote" color="secondary">{say('The people in your memories.','الأشخاص بذكرياتك.')}</Text><VStack className="ios-group" gap={0}>{items.length?items.map(item=><Row key={item.id} label={t(item.name)} sub={t(item.context)} leading={<Initials id={item.id}/>} onClick={()=>open({type:'person',id:item.id})}/>):<Empty/>}</VStack><Text className="ios-list-count" color="secondary">{items.length} {say('people','أشخاص')}</Text></VStack>;}
    if(page==='projects'){const items=projects.filter(item=>matches(t(item.name)+t(item.context)));return <VStack gap={6}>{items.length?<VStack className="ios-folders" gap={4}>{items.map(item=><VStack as="button" key={item.id} className="ios-folder" onClick={()=>open({type:'project',id:item.id})}><Icon icon={Folder} className="ios-folder-icon"/><Text className="ios-folder-name">{t(item.name)}</Text><Text className="ios-small" color="secondary">{item.count} {say('notes','ملاحظات')}</Text></VStack>)}</VStack>:<Empty/>}<VStack gap={2}><SectionLabel>{say('Related notes','ملاحظات مرتبطة')}</SectionLabel><VStack className="ios-group" gap={0}>{sources.filter(item=>matches(t(item.title)+t(item.text))).map(item=><Row key={item.id} label={t(item.title)} sub={t(item.date)} icon={FileText} onClick={()=>open({type:'source',id:item.id})}/>)}</VStack></VStack></VStack>;}
    if(page==='birthdays')return <VStack className="ios-birthdays" gap={6}><VStack className="ios-group ios-calendar" gap={5}><HStack className="ios-between"><Heading level={2}>{say('November','تشرين الثاني')}</Heading><Icon icon={CalendarDays} className="ios-accent-icon"/></HStack><HStack className="ios-week" gap={0}>{Array.from({length:7},(_,i)=>{const selected=i===6;return <VStack key={i} className="ios-week-day" gap={2}><Text className="ios-small" color="secondary">{ar?['ن','ث','ر','خ','ج','س','ح'][i]:['M','T','W','T','F','S','S'][i]}</Text>{selected?<Button label={say('Ali birthday, 15 November','عيد ميلاد علي، ١٥ تشرين الثاني')} className="ios-selected-day" onClick={()=>open({type:'birthday',id:'ali'})}>15</Button>:<Text className="ios-day-number">{i+9}</Text>}</VStack>})}</HStack><HStack as="button" className="ios-next-person" onClick={()=>open({type:'birthday',id:'ali'})}><Initials id="ali"/><VStack gap={1}><Text className="ios-row-title">{t(people[0].name)}</Text><Text className="ios-small" color="secondary">{t(people[0].birthday)}</Text></VStack><Icon icon={ar?ChevronLeft:ChevronRight} className="ios-chevron" size="sm"/></HStack></VStack><VStack gap={2}><SectionLabel>{say('Coming up','الجاي')}</SectionLabel><VStack className="ios-group"><Row label={t(people[1].name)} sub={t(people[1].birthday)} leading={<CalendarMark id="sara"/>} onClick={()=>open({type:'birthday',id:'sara'})}/></VStack><Text className="ios-section-footnote" color="secondary">{say('Open a birthday to preview its reminder.','افتح عيد ميلاد حتى تعاين التذكير.')}</Text></VStack></VStack>;
    if(page==='brainmap'){
      const nodes=[{id:'you',label:say('You','أنت'),icon:UserRound,x:50,y:47},{id:'ali',label:say('Ali','علي'),icon:UserRound,x:22,y:19},{id:'website',label:t(projects[0].name),icon:Folder,x:78,y:28},{id:'sara',label:say('Sara','سارة'),icon:UserRound,x:22,y:76},{id:'reading',label:t(projects[1].name),icon:Folder,x:77,y:79}];const node=nodes.find(item=>item.id===selectedNode);
      return <VStack gap={4}><HStack className="ios-segment" role="group" aria-label={say('Map view','طريقة العرض')} gap={0}><Button label={say('Map','الخريطة')} aria-pressed={!graphList} variant="ghost" onClick={()=>setGraphList(false)}/><Button label={say('List','القائمة')} aria-pressed={graphList} variant="ghost" onClick={()=>setGraphList(true)}/></HStack>{graphList?<VStack className="ios-group" gap={0}>{nodes.filter(item=>item.id!=='you').map(item=><Row key={item.id} label={item.label} sub={say('Connected through a sample note','مرتبط من خلال ملاحظة نموذجية')} icon={item.icon} onClick={()=>setSelectedNode(item.id)}/>)}</VStack>:<VStack className="ios-graph"><svg className="ios-graph-lines" viewBox="0 0 100 100" preserveAspectRatio="none" aria-hidden="true"><path d="M50 47Q26 43 22 19M50 47Q68 50 78 28M50 47Q27 52 22 76M50 47Q67 59 77 79M22 19Q60 8 78 28M22 76Q51 91 77 79"/></svg>{nodes.map(item=><VStack as="button" key={item.id} className={`ios-node node-${item.id}`} style={{insetInlineStart:`${item.x}%`,top:`${item.y}%`}} aria-label={item.label} aria-pressed={selectedNode===item.id} onClick={()=>setSelectedNode(item.id)}><VStack className="ios-node-symbol">{item.id==='ali'||item.id==='sara'?<Text>{ar?(item.id==='ali'?'ع':'س'):(item.id==='ali'?'AH':'SM')}</Text>:<Icon icon={item.icon} size="lg"/>}</VStack><Text className="ios-node-label">{item.label}</Text></VStack>)}</VStack>}{node&&<VStack className="ios-group ios-group-content" gap={3}><HStack className="ios-between"><Heading level={2} className="ios-small-heading">{node.label}</Heading><IconButton label={say('Close connection','إغلاق الرابط')} variant="ghost" icon={<Icon icon={X}/>} onClick={()=>setSelectedNode(null)}/></HStack><Text color="secondary">{node.id==='you'?say('Your notes connect these people and projects.','ملاحظاتك تربط هالأشخاص والمشاريع.'):say('Follow the connection to its original context.','اتبع الرابط حتى تشوف تفاصيله الأصلية.')}</Text>{node.id!=='you'&&<Button label={say('Open details','فتح التفاصيل')} variant="ghost" className="ios-link-button" onClick={()=>open({type:people.some(item=>item.id===node.id)?'person':'project',id:node.id})} endContent={<Icon icon={ar?ChevronLeft:ChevronRight}/>}/>}</VStack>}<Text className="ios-map-caption" color="secondary">{say('Tap a person or project to explore its connections.','اضغط على شخص أو مشروع حتى تستكشف روابطه.')}</Text></VStack>;
    }
    return <VStack className="ios-settings" gap={6}><VStack gap={2}><SectionLabel>{say('Appearance','المظهر')}</SectionLabel><VStack className="ios-group ios-group-content"><HStack className="ios-segment" role="group" aria-label={say('Appearance','المظهر')} gap={0}><Button label={say('Light','فاتح')} aria-pressed={appearance==='light'} variant="ghost" onClick={()=>setAppearance('light')}/><Button label={say('Dark','داكن')} aria-pressed={appearance==='dark'} variant="ghost" onClick={()=>setAppearance('dark')}/></HStack></VStack></VStack><VStack gap={2}><SectionLabel>{say('Language','اللغة')}</SectionLabel><VStack className="ios-group ios-group-content"><HStack className="ios-segment" gap={0}><Button label="English" aria-pressed={!ar} variant="ghost" onClick={()=>setLanguage('en')}/><Button label="العربية" aria-pressed={ar} variant="ghost" onClick={()=>setLanguage('ar')}/></HStack></VStack></VStack><VStack gap={2}><SectionLabel>{say('About this preview','عن المعاينة')}</SectionLabel><VStack className="ios-group ios-group-content" gap={3}><Text>{say('Explore MemoryOS with fictional people, notes, and connections.','جرّب MemoryOS بأشخاص وملاحظات وروابط خيالية.')}</Text><Text color="secondary">{say('Changes reset on reload. Recording and reminders are demonstrations.','التغييرات تنمسح لما تعيد تحميل الصفحة. التسجيل والتذكيرات للتجربة.')}</Text></VStack></VStack></VStack>;
  }
  return <Theme theme={theme} mode={appearance}><Styles/><VStack className={`ios-app ${detail?'is-detail':''}`} gap={0} style={dimensions} dir={ar?'rtl':'ltr'}>
    <HStack className="ios-toolbar"><Text className="ios-desktop-brand">MemoryOS</Text><Text className="ios-preview-label">{say('Sample library','مكتبة نموذجية')}</Text><HStack gap={1}><Button label={ar?'English':'العربية'} className="ios-language-button" variant="ghost" onClick={()=>setLanguage(ar?'en':'ar')}/><IconButton label={say('Settings','الإعدادات')} className="ios-settings-button" variant="ghost" icon={<Icon icon={Settings}/>} onClick={()=>navigate('settings')}/></HStack></HStack>
    <HStack className="ios-workspace" gap={0}><VStack as="nav" className="ios-tabs" aria-label={say('Main navigation','التنقل الرئيسي')} gap={1}>{nav.map(item=><Button key={item.id} label={t(item.label)} variant="ghost" className="ios-tab" aria-current={page===item.id?'page':undefined} onClick={()=>navigate(item.id)}><VStack className="ios-tab-content" gap={1}><Icon icon={item.icon} size="lg"/><Text type="inherit">{t(item.label)}</Text></VStack></Button>)}</VStack><Layout className="ios-shell" height="fill" padding={0}
      header={<LayoutHeader className={`ios-header ${detail?'ios-header-detail':''}`}><HStack className="ios-between" gap={3}>{detail&&<IconButton label={say('Back','رجوع')} variant="ghost" className="ios-back" icon={<Icon icon={ar?ChevronRight:ChevronLeft} size="lg"/>} onClick={back}/>}<Heading level={1} className="ios-title">{title}</Heading></HStack>{!detail&&page==='capture'&&<Text className="ios-subtitle" color="secondary">{say('A place for the things you want to remember.','مكان للأشياء اللي تحب تتذكرها.')}</Text>}{!detail&&(page==='people'||page==='projects')&&<SearchField/>}</LayoutHeader>}
      content={<LayoutContent className="ios-content"><VStack as="main" className="ios-main" data-screen={page} gap={0}>{content()}</VStack></LayoutContent>}
    /></HStack>
    {notice&&<VStack className="ios-notice" role="status"><HStack gap={2}><Icon icon={Check} size="sm"/><Text>{notice}</Text></HStack></VStack>}
    <BottomSheet label={say('Sample attachments','مرفقات نموذجية')} isOpen={attachmentOpen} onOpenChange={setAttachmentOpen} className="ios-attachment-sheet" style={dimensions}><VStack gap={4}><HStack className="ios-between"><Heading level={2} className="ios-small-heading">{say('Add a sample note','أضف ملاحظة نموذجية')}</Heading><IconButton label={say('Close attachments','إغلاق المرفقات')} variant="ghost" icon={<Icon icon={X}/>} onClick={()=>setAttachmentOpen(false)}/></HStack><Text color="secondary">{say('Choose a fictional note to try this flow.','اختار ملاحظة خيالية حتى تجرّب هالخطوة.')}</Text><VStack className="ios-group" gap={0}>{sources.map(item=><Row key={item.id} label={t(item.title)} sub={t(item.date)} icon={Paperclip} onClick={()=>{submit(t(item.text));setAttachmentOpen(false)}}/>)}</VStack></VStack></BottomSheet>
  </VStack></Theme>;
}
