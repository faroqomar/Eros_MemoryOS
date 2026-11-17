#!/usr/bin/env python3
"""Produce fictional local TTS fixtures; these do not establish Iraqi accent accuracy."""
import hashlib
import json
from pathlib import Path
import random
import struct
import subprocess
import sys
import tempfile
import wave

ROOT=Path(__file__).resolve().parents[1]
DEST=Path(sys.argv[1]).resolve() if len(sys.argv)>1 else ROOT/'native/verification/audio-step1/fixtures'
CASES=[
 ('english','Samantha','Tomorrow I will meet Maya at the library at ten. We will review the garden project.'),
 ('iraqi_text_synthetic','Majed','شلونك علي؟ باچر نروح للسوق الساعة عشرة، وبعدين نشوف زينب بالمكتبة.'),
 ('mixed','Majed','باچر عدنا meeting ويا سارة حتى نراجع project plan ونرسل email لعلي.'),
 ('names','Samantha','Maya Hassan and Daniel Omar will meet at the River Library on Tuesday.'),
]
DEST.mkdir(parents=True,exist_ok=True)
rows=[]
with tempfile.TemporaryDirectory(prefix='memoryos-tts-') as temporary:
 for identifier,voice,text in CASES:
  aiff=Path(temporary)/f'{identifier}.aiff'
  path=DEST/f'{identifier}.wav'
  subprocess.run(['say','-v',voice,'-r','145','-o',str(aiff),text],check=True)
  subprocess.run(['ffmpeg','-hide_banner','-loglevel','error','-y','-i',str(aiff),'-ar','16000','-ac','1','-c:a','pcm_s16le',str(path)],check=True)
  with wave.open(str(path),'rb') as wav: duration=wav.getnframes()/wav.getframerate()
  rows.append({'id':identifier,'file':path.name,'expected':text,'voice':voice,'durationSeconds':duration,
    'sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'synthetic':True})
source=DEST/'english.wav'
with wave.open(str(source),'rb') as wav:
 params=wav.getparams(); raw=wav.readframes(wav.getnframes())
values=struct.unpack('<'+'h'*(len(raw)//2),raw)
rng=random.Random(6122026)
noisy=[max(-32768,min(32767,round(sample*0.7+rng.gauss(0,1800)))) for sample in values]
noise_path=DEST/'background_noise.wav'
with wave.open(str(noise_path),'wb') as wav:
 wav.setparams(params);wav.writeframes(struct.pack('<'+'h'*len(noisy),*noisy))
rows.append({**rows[0],'id':'background_noise','file':noise_path.name,'noise':'seeded Gaussian noise sigma1800 with speech gain0.7',
 'sha256':hashlib.sha256(noise_path.read_bytes()).hexdigest()})
(DEST/'manifest.json').write_text(json.dumps({'version':1,'limitations':['System TTS, not human speech.','Iraqi wording uses an Arabic World TTS voice; dialect/accent quality remains untested.','Mixed TTS pronunciation may differ from natural code switching.'], 'recordings':rows},ensure_ascii=False,indent=2)+'\n')
print(json.dumps({'recordings':len(rows),'directory':str(DEST),'seconds':sum(x['durationSeconds'] for x in rows)}))
