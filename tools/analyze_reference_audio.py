"""Optional reference analysis. Numeric descriptors only; no reference audio is shipped.

Requires numpy and the locally decoded reference/analysis/new_audio.wav.
Mixed music/effects preclude attributing peaks or RMS changes solely to engine audio.
"""
import json
from pathlib import Path
import wave
import numpy as np

root = Path(__file__).resolve().parents[1]
with wave.open(str(root / 'reference/analysis/new_audio.wav'), 'rb') as w:
    rate = w.getframerate()
    channels = w.getnchannels()
    assert w.getsampwidth() == 2
    pcm = np.frombuffer(w.readframes(w.getnframes()), dtype='<i2').astype(float) / 32768
    pcm = pcm.reshape(-1, channels).mean(axis=1)

windows = [('idle',1.3,1.7), ('launch',6.8,7.2),
           ('before_shift1',8.2,8.4), ('shift1',8.5,8.9), ('after_shift1',9.1,9.5),
           ('before_shift2',13.8,14.0), ('shift2',14.1,14.6), ('after_shift2',15.0,15.4),
           ('clutch_coast',18.8,19.2), ('loaded_third',20.8,21.2)]
rows = []
for label, start, end in windows:
    x = pcm[round(start*rate):round(end*rate)]
    power = np.abs(np.fft.rfft(x*np.hanning(len(x))))**2
    frequencies = np.fft.rfftfreq(len(x),1/rate)
    useful = (frequencies >= 40) & (frequencies <= 6000)
    centroid = float(np.sum(frequencies[useful]*power[useful]) / max(1e-12, power[useful].sum()))
    dominant = float(frequencies[np.flatnonzero(useful)[np.argmax(power[useful])]])
    rows.append({'label': label,'video_start_s':start,'video_end_s':end,
                 'mix_rms_dbfs':float(20*np.log10(max(1e-12,np.sqrt(np.mean(x*x))))),
                 'mix_power_centroid_hz':centroid,'mix_dominant_hz':dominant})
result = {'source':'LCXM2683.MP4 / locally decoded audio','sample_rate':rate,'duration_s':len(pcm)/rate,
          'windows':rows,'limitations':'These are measurements of mixed game audio including music. Dominant peaks are not asserted to be engine firing frequency, nor are RMS changes isolated engine load. RPM/shift timing is grounded in the separately transcribed HUD. JLTI6246.MP4 has a silent decoded track. No samples are copied into the game.'}
(root/'validation/reference_audio_analysis.json').write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps(result,indent=2))
