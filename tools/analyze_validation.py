"""Frozen replay acceptance checks and independent WAV frequency measurement.

Python standard library only. Does not refit parameters or read protected audio.
"""
import array
import cmath
import json
import math
from pathlib import Path
import sys
import wave

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'validation'


def tone_frequency(path, expected):
    with wave.open(str(path), 'rb') as wav:
        assert wav.getsampwidth() == 2 and wav.getnchannels() == 1
        sample_rate = wav.getframerate()
        samples = array.array('h', wav.readframes(wav.getnframes()))
    if sys.byteorder != 'little':
        samples.byteswap()
    # Two-second Hann-windowed direct DFT, 0.5 Hz bins around expected firing rate.
    scores = {}
    for offset in range(-8, 9):
        hz = expected + offset * 0.5
        rotation = cmath.exp(-2j * cmath.pi * hz / sample_rate)
        phase = 1 + 0j
        total = 0j
        for i, sample in enumerate(samples):
            weight = 0.5 - 0.5 * cmath.cos(2 * cmath.pi * i / (len(samples) - 1)).real
            total += sample * weight * phase
            phase *= rotation
        scores[hz] = abs(total)
    measured = max(scores, key=scores.get)
    return {'expected_hz': expected, 'measured_hz': measured,
            'peak_pcm_amplitude': max(abs(s) for s in samples) / 32768,
            'passed': abs(measured - expected) <= 0.5}


def main():
    comparison = json.loads((OUT / 'reference_comparison.json').read_text())
    measured, reference = comparison['after'], comparison['observed_slip']
    checks = {
        'quarter_et_within_0.25_s': abs(measured['et_s'] - reference['elapsed_s']) < 0.25,
        'trap_within_2_mph': abs(measured['trap_mph'] - reference['quarter_mph']) < 2,
        'speed_rmse_below_2_mph': measured['speed_rmse_mph'] < 2,
        'loaded_rpm_rmse_below_250': measured['loaded_rpm_rmse'] < 250,
        'launch_rpm_max_error_below_1000': measured['launch_max_rpm_error'] < 1000,
        'sixty_ft_within_0.25_s': abs(measured['sixty_ft_et_s'] - reference['sixty_ft_s']) < 0.25,
        'eighth_within_0.25_s': abs(measured['eighth_et_s'] - reference['eighth_s']) < 0.25,
    }
    audio = {str(cyl): tone_frequency(OUT / f'audio_{cyl}cyl_3000.wav', 3000 / 60 * cyl / 2)
             for cyl in (4, 6)}
    acceleration_rows = []
    by_time = {r['clock_s']: r for r in comparison['before']['differences']}
    samples = measured['differences']
    for left, right in zip(samples, samples[1:]):
        dt = right['clock_s'] - left['clock_s']
        if right['clock_s'] > 19.517 or not 0.9 < dt < 1.1:
            continue
        old_left, old_right = by_time[left['clock_s']], by_time[right['clock_s']]
        convert = 0.44704 / dt
        observed = (right['reference_mph'] - left['reference_mph']) * convert
        previous = (old_right['simulated_mph'] - old_left['simulated_mph']) * convert
        current = (right['simulated_mph'] - left['simulated_mph']) * convert
        acceleration_rows.append({'start_clock_s': left['clock_s'], 'end_clock_s': right['clock_s'],
                                  'gear_start': left['gear_observed'], 'gear_end': right['gear_observed'],
                                  'observed_mean_mps2': observed, 'previous_mean_mps2': previous,
                                  'corrected_mean_mps2': current})
    acceleration = {'rows': acceleration_rows,
                    'previous_rmse_mps2': math.sqrt(sum((r['previous_mean_mps2'] - r['observed_mean_mps2']) ** 2 for r in acceleration_rows) / len(acceleration_rows)),
                    'corrected_rmse_mps2': math.sqrt(sum((r['corrected_mean_mps2'] - r['observed_mean_mps2']) ** 2 for r in acceleration_rows) / len(acceleration_rows)),
                    'note': 'Derived interval-average acceleration from 1 s HUD-speed differences, including launches/shifts/coasting. Not instantaneous acceleration or recovered wheel force. Integer speed quantization alone allows about +/-0.447 m/s^2 interval error; clock-reading uncertainty adds error.'}
    (OUT / 'acceleration_comparison.json').write_text(json.dumps(acceleration, indent=2) + '\n')
    passed = all(checks.values()) and all(row['passed'] for row in audio.values())
    result = {'passed': passed, 'reference_checks': checks, 'audio_firing_frequency': audio,
              'interval_acceleration_rmse_mps2': acceleration['corrected_rmse_mps2'],
              'note': 'Acceptance is a regression check on a fitted replay with estimated inputs, not independent recovery of the reference physics. Hardware sound latency and exact timbre remain unverified.'}
    (OUT / 'analysis_results.json').write_text(json.dumps(result, indent=2) + '\n')
    print(json.dumps(result, indent=2))
    return 0 if passed else 1


if __name__ == '__main__':
    sys.exit(main())
