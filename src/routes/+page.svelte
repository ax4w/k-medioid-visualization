<script lang="ts">
	import { onMount, onDestroy } from 'svelte';
	import { Chart } from 'chart.js/auto';
	import type { ChartData } from 'chart.js';

	// Types
	type Point = { x: number; y: number };
	type Dataset = { label: string; data: Point[] };
	type PointWithTotalDistance = { p: Point; td: number };
	type Cluster = Map<Point, Point[]>;

	// Constants
	const BOUNDS = {
		minX: -10000,
		maxX: 10000,
		minY: -10000,
		maxY: 10000,
		clusterSpread: 1500,
		maxDatasetSize: 300
	} as const;

	// State Management
	let chartRef: HTMLCanvasElement | null = null;
	let chartInstance: Chart | null = null;
	let clusters: Cluster = new Map();
	let medioids: Point[] = [];
	let numMedioids: number = 3;
	let data: ChartData<'scatter', Point[]> = { datasets: [] };

	// Utility Functions
	function randomInt(min: number, max: number): number {
		return Math.floor(Math.random() * (max - min + 1) + min);
	}

	function randomRGBA(): string {
		return `rgba(${randomInt(0, 255)},${randomInt(0, 255)},${randomInt(0, 255)},1)`;
	}

	function pointToString(p: Point): string {
		return `${p.x},${p.y}`;
	}

	// Distance Calculations
	function calculateDistance(p1: Point, p2: Point): number {
		return Math.abs(p1.x - p2.x) + Math.abs(p1.y - p2.y);
	}

	function calculateAllDistances(points: Point[]): PointWithTotalDistance[] {
		if (!points.length) return [];

		return points
			.map(point => ({
				p: point,
				td: points.reduce((sum, other) => sum + calculateDistance(point, other), 0)
			}))
			.sort((a, b) => a.td - b.td);
	}

	// Medioid Functions
	function findNearestMedioid(point: Point, medioidList: Point[]): Point | null {
		if (!medioidList.length) return null;

		return medioidList.reduce((nearest, medioid) => {
			const distance = calculateDistance(point, medioid);
			if (!nearest || distance < calculateDistance(point, nearest)) {
				return medioid;
			}
			return nearest;
		}, null as Point | null);
	}

	function initializeMedioids(): void {
		if (!data.datasets.length) return;

		const allPoints = data.datasets.flatMap(d => d.data);
		if (!allPoints.length) {
			alert('Please add at least one dataset first!');
			return;
		}

		const actualNumMedioids = Math.min(numMedioids, allPoints.length);
		const selectedIndices = new Set<number>();
		medioids = [];

		while (medioids.length < actualNumMedioids) {
			const randomIndex = randomInt(0, allPoints.length - 1);
			if (!selectedIndices.has(randomIndex)) {
				selectedIndices.add(randomIndex);
				medioids.push(allPoints[randomIndex]);
			}
		}

		clusterAll();
		updateChart();
	}

	// Clustering Logic
	function clusterAll(): void {
		if (!data.datasets?.length || !medioids.length) {
			console.warn('No datasets or medioids available for clustering');
			return;
		}

		const allPoints = data.datasets.flatMap(d => d.data);
		if (!allPoints.length) {
			console.warn('No points available for clustering');
			return;
		}

		// Initialize and populate clusters
		clusters = new Map(medioids.map(m => [m, [] as Point[]]));
		
		allPoints.forEach(point => {
			const nearestMedioid = findNearestMedioid(point, medioids);
			if (nearestMedioid) {
				const cluster = clusters.get(nearestMedioid) ?? [];
				cluster.push(point);
				clusters.set(nearestMedioid, cluster);
			}
		});

		updateDatasets();
	}

	function clusterOneIteration(): boolean {
		if (!medioids.length) return false;

		// Find new medioids for each cluster
		const newMedioids = Array.from(clusters.entries()).map(([key, points]) => {
			const distances = calculateAllDistances(points);
			return distances.length > 0 ? distances[0].p : key;
		});

		if (!newMedioids.length) return false;

		// Check convergence
		const oldMedioidStrings = new Set(medioids.map(pointToString));
		const newMedioidStrings = new Set(newMedioids.map(pointToString));
		const hasConverged = medioids.length === newMedioids.length && 
			newMedioids.every(m => oldMedioidStrings.has(pointToString(m)));

		if (hasConverged) return false;

		medioids = newMedioids;
		clusterAll();
		updateChart();
		return true;
	}

	function clusterTillEnd(): void {
		while (clusterOneIteration()) { /* continue until convergence */ }
	}

	// Data Generation
	function generateDatasetWithRandomSize(): Dataset {
		const size = randomInt(1, BOUNDS.maxDatasetSize);
		const center = {
			x: randomInt(BOUNDS.minX, BOUNDS.maxX),
			y: randomInt(BOUNDS.minY, BOUNDS.maxY)
		};
		const points = [center];

		for (let i = 0; i < size; i++) {
			points.push({
				x: center.x + randomInt(-BOUNDS.clusterSpread, BOUNDS.clusterSpread),
				y: center.y + randomInt(-BOUNDS.clusterSpread, BOUNDS.clusterSpread)
			});
		}

		return {
			label: `Dataset-${data.datasets.length}`,
			data: points
		};
	}

	// Chart Management
	function updateDatasets(): void {
		data.datasets = Array.from(clusters.entries()).map(([_, points], index) => ({
			label: `Cluster-${index}`,
			data: points,
			backgroundColor: randomRGBA()
		}));
	}

	function updateChart(): void {
		chartInstance?.update();
	}

	// Lifecycle
	onMount(() => {
		if (chartRef) {
			chartInstance = new Chart(chartRef, {
				type: 'scatter',
				data,
				options: {
					responsive: true,
					maintainAspectRatio: false,
					scales: {
						x: { type: 'linear', position: 'bottom' }
					}
				}
			});
		}
	});

	onDestroy(() => {
		chartInstance?.destroy();
		chartInstance = null;
	});
</script>

<div class="h-screen bg-gradient-to-br from-gray-50 to-gray-100 overflow-hidden flex flex-col">
    <div class="flex-1 py-6 px-4 sm:px-6 lg:px-8 overflow-y-auto">
        <div class="max-w-4xl mx-auto h-full flex flex-col">
            <header class="text-center mb-6">
                <h1 class="text-3xl font-bold text-gray-900">K-Medioid Clustering</h1>
                <p class="mt-2 text-sm text-gray-600">Interactive visualization of K-Medioid clustering algorithm</p>
            </header>
            
            <div class="flex-1 bg-white p-6 rounded-xl shadow-lg mb-6">
                <div class="h-full flex items-center justify-center">
                    <canvas bind:this={chartRef} class="max-h-full w-full"></canvas>
                </div>
            </div>

            <div class="space-y-4">
                <div class="bg-white p-4 rounded-xl shadow-lg">
                    <div class="flex items-center justify-between">
                        <div class="flex items-center space-x-4">
                            <label for="numMedioids" class="text-gray-700 font-medium">Number of Medioids:</label>
                            <input 
                                id="numMedioids"
                                type="number" 
                                bind:value={numMedioids} 
                                min="1" 
                                max="10" 
                                class="shadow-sm rounded-md border-gray-300 focus:ring-indigo-500 focus:border-indigo-500 sm:text-sm w-20"
                            />
                        </div>
                        <span class="text-xs text-gray-500">Range: 1-10</span>
                    </div>
                </div>

                <div class="flex gap-4 pb-4">
                    <button
                        class="flex-1 bg-indigo-600 text-white px-6 py-3 rounded-lg hover:bg-indigo-700 
                               focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500 
                               transition-all transform hover:scale-102 active:scale-98 shadow-md"
                        on:click={() => {
                            const dataset = generateDatasetWithRandomSize();
                            data.datasets = [...data.datasets, {
                                ...dataset,
                                backgroundColor: randomRGBA()
                            }];
                            updateChart();
                        }}
                    >
                        Add Random Dataset
                    </button>
                    
                    <button
                        class="flex-1 bg-green-600 text-white px-6 py-3 rounded-lg hover:bg-green-700 
                               focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-green-500 
                               transition-all transform hover:scale-102 active:scale-98 shadow-md"
                        on:click={() => {
                            initializeMedioids();
                            clusterTillEnd();
                        }}
                    >
                        Run Clustering
                    </button>
                </div>
            </div>
        </div>
    </div>
</div>