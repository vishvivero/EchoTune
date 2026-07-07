#!/usr/bin/env python3
"""
EchoTune Performance Analysis Script
Analyzes benchmark results and generates detailed reports
"""

import csv
import sys
import statistics
from datetime import datetime
from pathlib import Path

class PerformanceAnalyzer:
    def __init__(self, csv_file):
        self.csv_file = csv_file
        self.results = []
        self.load_results()

    def load_results(self):
        """Load benchmark results from CSV"""
        try:
            with open(self.csv_file, 'r') as f:
                reader = csv.DictReader(f)
                self.results = list(reader)
            print(f"✅ Loaded {len(self.results)} benchmark results")
        except FileNotFoundError:
            print(f"❌ Error: File not found: {self.csv_file}")
            sys.exit(1)
        except Exception as e:
            print(f"❌ Error loading CSV: {e}")
            sys.exit(1)

    def calculate_statistics(self, values):
        """Calculate statistics for a list of values"""
        if not values:
            return {}

        return {
            'min': min(values),
            'max': max(values),
            'mean': statistics.mean(values),
            'median': statistics.median(values),
            'stdev': statistics.stdev(values) if len(values) > 1 else 0
        }

    def analyze_by_phase(self):
        """Analyze performance by phase"""
        print("\n" + "="*60)
        print("📊 PERFORMANCE ANALYSIS BY PHASE")
        print("="*60)

        phases = {}
        for result in self.results:
            phase = result.get('Phase', 'Unknown')
            if phase not in phases:
                phases[phase] = []
            phases[phase].append(result)

        for phase, results in sorted(phases.items()):
            print(f"\n{phase}:")
            print("-" * 40)

            # Extract RTF values
            rtf_values = []
            latency_values = []
            transcription_times = []

            for r in results:
                try:
                    rtf = float(r.get('RTF', 0))
                    latency = float(r.get('Total (s)', 0))
                    trans_time = float(r.get('Transcription (s)', 0))

                    rtf_values.append(rtf)
                    latency_values.append(latency)
                    if trans_time > 0:
                        transcription_times.append(trans_time)
                except (ValueError, TypeError):
                    continue

            if rtf_values:
                rtf_stats = self.calculate_statistics(rtf_values)
                print(f"  RTF: {rtf_stats['mean']:.3f}x (avg)")
                print(f"       {rtf_stats['min']:.3f}x - {rtf_stats['max']:.3f}x (range)")

                latency_stats = self.calculate_statistics(latency_values)
                print(f"  Latency: {latency_stats['mean']:.3f}s (avg)")

                if transcription_times:
                    trans_stats = self.calculate_statistics(transcription_times)
                    print(f"  Transcription: {trans_stats['mean']:.3f}s (avg)")

                print(f"  Tests: {len(results)}")

    def compare_phases(self):
        """Compare performance between phases"""
        print("\n" + "="*60)
        print("📈 PHASE COMPARISON")
        print("="*60)

        # Group by phase
        phase_metrics = {}
        for result in self.results:
            phase = result.get('Phase', 'Unknown')

            try:
                rtf = float(result.get('RTF', 0))
                latency = float(result.get('Total (s)', 0))
                duration = float(result.get('Duration (s)', 0))

                if phase not in phase_metrics:
                    phase_metrics[phase] = {'rtf': [], 'latency': [], 'duration': []}

                phase_metrics[phase]['rtf'].append(rtf)
                phase_metrics[phase]['latency'].append(latency)
                phase_metrics[phase]['duration'].append(duration)
            except (ValueError, TypeError):
                continue

        # Calculate averages
        phase_averages = {}
        for phase, metrics in phase_metrics.items():
            if metrics['rtf']:
                phase_averages[phase] = {
                    'rtf': statistics.mean(metrics['rtf']),
                    'latency': statistics.mean(metrics['latency']),
                }

        # Compare phases
        if len(phase_averages) >= 2:
            phases = sorted(phase_averages.keys())
            print(f"\n{'Phase':<15} {'Avg RTF':<12} {'Avg Latency':<15} {'vs Baseline':<15}")
            print("-" * 60)

            baseline = None
            baseline_name = None

            for phase in phases:
                metrics = phase_averages[phase]
                improvement = ""

                if baseline is None:
                    baseline = metrics['latency']
                    baseline_name = phase
                    improvement = "(baseline)"
                else:
                    speedup = baseline / metrics['latency']
                    percent = ((baseline - metrics['latency']) / baseline) * 100
                    improvement = f"{speedup:.2f}x ({percent:.1f}% faster)"

                print(f"{phase:<15} {metrics['rtf']:<12.3f} {metrics['latency']:<15.3f} {improvement}")

    def analyze_vad_impact(self):
        """Analyze VAD impact on performance"""
        print("\n" + "="*60)
        print("🎯 VAD IMPACT ANALYSIS")
        print("="*60)

        vad_skipped = [r for r in self.results if r.get('VAD Skipped', '').upper() == 'YES']
        vad_processed = [r for r in self.results if r.get('VAD Skipped', '').upper() == 'NO']

        print(f"\nVAD Skipped Transcription: {len(vad_skipped)} tests")
        if vad_skipped:
            latencies = [float(r.get('Total (s)', 0)) for r in vad_skipped if r.get('Total (s)')]
            if latencies:
                avg_latency = statistics.mean(latencies)
                print(f"  Average latency: {avg_latency:.3f}s")
                print(f"  🚀 Skipping saved ~{8.0 - avg_latency:.1f}s per recording (vs full transcription)")

        print(f"\nVAD Processed (Speech Detected): {len(vad_processed)} tests")
        if vad_processed:
            latencies = [float(r.get('Total (s)', 0)) for r in vad_processed if r.get('Total (s)')]
            if latencies:
                avg_latency = statistics.mean(latencies)
                print(f"  Average latency: {avg_latency:.3f}s")

    def check_targets(self):
        """Check if performance targets are met"""
        print("\n" + "="*60)
        print("🎯 PERFORMANCE TARGET VALIDATION")
        print("="*60)

        # Target: RTF < 0.2x for Phase 3
        phase3_results = [r for r in self.results if r.get('Phase', '').lower().startswith('phase 3')]

        if phase3_results:
            rtf_values = []
            for r in phase3_results:
                try:
                    rtf = float(r.get('RTF', 0))
                    if rtf > 0:
                        rtf_values.append(rtf)
                except (ValueError, TypeError):
                    continue

            if rtf_values:
                avg_rtf = statistics.mean(rtf_values)
                target_rtf = 0.2

                print(f"\nPhase 3 Target: RTF < {target_rtf}x")
                print(f"Actual: RTF = {avg_rtf:.3f}x")

                if avg_rtf < target_rtf:
                    margin = ((target_rtf - avg_rtf) / target_rtf) * 100
                    print(f"✅ TARGET MET! ({margin:.1f}% better than target)")
                else:
                    shortfall = ((avg_rtf - target_rtf) / target_rtf) * 100
                    print(f"❌ TARGET MISSED ({shortfall:.1f}% slower than target)")
        else:
            print("\n⚠️  No Phase 3 results found")

    def generate_report(self):
        """Generate comprehensive markdown report"""
        report_path = Path(self.csv_file).parent / f"analysis_report_{datetime.now().strftime('%Y%m%d_%H%M%S')}.md"

        with open(report_path, 'w') as f:
            f.write("# EchoTune Performance Analysis Report\n\n")
            f.write(f"**Generated:** {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n\n")
            f.write(f"**Data Source:** {self.csv_file}\n\n")

            # System info from first result
            if self.results:
                r = self.results[0]
                f.write("## System Information\n\n")
                f.write(f"- **Device:** {r.get('Device', 'Unknown')}\n")
                f.write(f"- **CPU:** {r.get('CPU', 'Unknown')}\n")
                f.write(f"- **OS:** {r.get('OS', 'Unknown')}\n")
                f.write(f"- **Metal:** {r.get('Metal', 'Unknown')}\n\n")

            # Summary table
            f.write("## Performance Summary\n\n")
            f.write("| Phase | Tests | Avg RTF | Avg Latency | Min RTF | Max RTF |\n")
            f.write("|-------|-------|---------|-------------|---------|----------|\n")

            phases = {}
            for result in self.results:
                phase = result.get('Phase', 'Unknown')
                if phase not in phases:
                    phases[phase] = []
                phases[phase].append(result)

            for phase, results in sorted(phases.items()):
                rtf_values = []
                latency_values = []

                for r in results:
                    try:
                        rtf = float(r.get('RTF', 0))
                        latency = float(r.get('Total (s)', 0))
                        if rtf > 0:
                            rtf_values.append(rtf)
                            latency_values.append(latency)
                    except (ValueError, TypeError):
                        continue

                if rtf_values:
                    rtf_stats = self.calculate_statistics(rtf_values)
                    latency_stats = self.calculate_statistics(latency_values)

                    f.write(f"| {phase} | {len(results)} | {rtf_stats['mean']:.3f}x | {latency_stats['mean']:.3f}s | {rtf_stats['min']:.3f}x | {rtf_stats['max']:.3f}x |\n")

            f.write("\n## Detailed Analysis\n\n")
            f.write("See console output for detailed breakdown.\n")

        print(f"\n📄 Report saved to: {report_path}")

    def run_analysis(self):
        """Run complete analysis"""
        print("\n🔬 EchoTune Performance Analysis")
        print(f"📁 Analyzing: {self.csv_file}")

        self.analyze_by_phase()
        self.compare_phases()
        self.analyze_vad_impact()
        self.check_targets()
        self.generate_report()

        print("\n" + "="*60)
        print("✅ Analysis complete!")
        print("="*60)


def main():
    if len(sys.argv) < 2:
        print("Usage: python3 analyze_performance.py <benchmark_results.csv>")
        print("\nExample:")
        print("  python3 Scripts/analyze_performance.py BenchmarkResults/metrics.csv")
        sys.exit(1)

    csv_file = sys.argv[1]
    analyzer = PerformanceAnalyzer(csv_file)
    analyzer.run_analysis()


if __name__ == "__main__":
    main()
