import type {Metadata} from 'next';
import '@astryxdesign/core/reset.css';
import '@astryxdesign/core/astryx.css';

export const metadata: Metadata = {
  title: 'MemoryOS · Astryx design',
  description: 'A clickable MemoryOS interface study with fictional sample data.',
};

export default function RootLayout({children}: {children: React.ReactNode}) {
  return <html lang="en"><body style={{margin: 0}}>{children}</body></html>;
}
