export type Copy = {en: string; ar: string};
export const copy = (en: string, ar: string): Copy => ({en, ar});
export const people = [
  {id: 'ali', name: copy('Ali Hassan', 'علي حسن'), initials: 'AH', birthday: copy('15 November', '١٥ تشرين الثاني'), day: '15', month: copy('NOV', 'ت٢'), project: 'website', source: 'website', context: copy('A quieter website, with room for the work.', 'موقع أبسط يخلّي الأعمال هي الأساس.'), about: copy('A friend from university. We exchange ideas about design.', 'صديق من الجامعة. نتبادل أفكار عن التصميم.')},
  {id: 'sara', name: copy('Sara Mahmoud', 'سارة محمود'), initials: 'SM', birthday: copy('23 December', '٢٣ كانون الأول'), day: '23', month: copy('DEC', 'ك١'), project: 'reading', source: 'reading', context: copy('The book we want to read next.', 'الكتاب اللي نريد نقرأه بعدين.'), about: copy('We share books and keep a small reading list.', 'نتبادل كتب وعندنا قائمة قراءة صغيرة.')},
  {id: 'omar', name: copy('Omar Khalid', 'عمر خالد'), initials: 'OK', birthday: copy('Not added', 'غير مضاف'), day: '', month: copy('', ''), project: 'website', source: 'idea', context: copy('An idea for showing the first draft.', 'فكرة لعرض النسخة الأولى.'), about: copy('We often talk through early project ideas.', 'نتناقش عادةً بأفكار المشاريع الجديدة.')},
];
export const projects = [
  {id: 'website', name: copy('Website refresh', 'تجديد الموقع'), context: copy('A simpler home for the work.', 'مكان أبسط لعرض الأعمال.'), plan: copy('Start with a small selection of projects. Keep the page simple.', 'نبدأ بمجموعة صغيرة من المشاريع ونخلي الصفحة بسيطة.'), idea: copy('I might prepare a first draft next week.', 'ممكن أحضّر مسودة أولى الأسبوع الجاي.'), person: 'ali', source: 'website', count: 3},
  {id: 'reading', name: copy('Reading journal', 'دفتر القراءة'), context: copy('Books, thoughts, and things to return to.', 'كتب وأفكار وأشياء نرجعلها.'), plan: copy('Keep a short note from each book, in our own words.', 'نحتفظ بملاحظة قصيرة من كل كتاب بكلامنا.'), idea: copy('Perhaps we could read the next book together.', 'يمكن نقرأ الكتاب الجاي سوا.'), person: 'sara', source: 'reading', count: 2},
];
export const sources = [
  {id: 'website', title: copy('A conversation with Ali', 'حديث مع علي'), date: copy('12 November · Text note', '١٢ تشرين الثاني · ملاحظة نصية'), text: copy('Ali and I talked about the website. He liked the idea of a quiet page with a few selected projects. I might prepare a first draft next week. His birthday is 15 November.', 'حچيت ويا علي عن الموقع. عجبه يكون بسيط وبيه مجموعة أعمال مختارة. ممكن أحضّر مسودة أولى الأسبوع الجاي. عيد ميلاده ١٥ تشرين الثاني.')},
  {id: 'reading', title: copy('Books to come back to', 'كتب نرجعلها'), date: copy('10 November · Text note', '١٠ تشرين الثاني · ملاحظة نصية'), text: copy('Sara suggested keeping one thought from every book. We might read the next one together. Her birthday is 23 December.', 'سارة اقترحت نحتفظ بفكرة من كل كتاب. يمكن نقرأ الكتاب الجاي سوا. عيد ميلادها ٢٣ كانون الأول.')},
  {id: 'idea', title: copy('An idea from Omar', 'فكرة من عمر'), date: copy('8 November · Text note', '٨ تشرين الثاني · ملاحظة نصية'), text: copy('Omar suggested showing the website draft to a few friends before adding more pages. We have not decided yet.', 'عمر اقترح نعرض مسودة الموقع على كم صديق قبل ما نضيف صفحات ثانية. بعدنا ما قررنا.')},
];
export type Page = 'capture' | 'people' | 'projects' | 'birthdays' | 'brainmap' | 'settings';
export type Detail = {type: 'person' | 'project' | 'source' | 'birthday' | 'note'; id: string} | null;
