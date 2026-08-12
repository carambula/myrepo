// Test calculations for SpinMin tire pressure calculator

const TirePressureCalculator = {
    bikeTypes: {
        road: { weight: 8.0, distribution: { front: 0.48, rear: 0.52 }, multiplier: 0.95 },
        gravel: { weight: 9.5, distribution: { front: 0.47, rear: 0.53 }, multiplier: 0.85 },
        mountainXC: { weight: 12.0, distribution: { front: 0.465, rear: 0.535 }, multiplier: 0.75 },
        mountainTrail: { weight: 13.5, distribution: { front: 0.465, rear: 0.535 }, multiplier: 0.65 },
        mountainEnduro: { weight: 15.0, distribution: { front: 0.465, rear: 0.535 }, multiplier: 0.55 },
        fat: { weight: 16.0, distribution: { front: 0.47, rear: 0.53 }, multiplier: 0.35 }
    },
    
    terrainMultipliers: {
        smooth: 1.0,
        mixed: 0.95,
        rough: 0.90,
        gravel1: 0.88,
        gravel2: 0.85,
        gravel3: 0.82,
        gravel4: 0.78,
        trail: 0.75,
        technical: 0.70
    },
    
    casingAdjustments: {
        supple: -2.0,
        standard: 0.0,
        reinforced: 3.0
    },
    
    ridingStyleAdjustments: {
        comfort: -3.0,
        balanced: 0.0,
        performance: 2.0
    },
    
    calculateBasePressure(weightLbs, tireWidthMM, bikeType) {
        const tireWidthInches = tireWidthMM / 25.4;
        const baseMultiplier = this.bikeTypes[bikeType].multiplier;
        return (weightLbs * baseMultiplier) / Math.pow(tireWidthInches, 1.5);
    },
    
    clampPressure(pressure, tireWidthMM, bikeType) {
        let minPressure, maxPressure;
        
        if (bikeType === 'road') {
            if (tireWidthMM < 25) {
                [minPressure, maxPressure] = [80, 130];
            } else if (tireWidthMM < 32) {
                [minPressure, maxPressure] = [60, 100];
            } else {
                [minPressure, maxPressure] = [45, 85];
            }
        } else if (bikeType === 'gravel') {
            if (tireWidthMM < 35) {
                [minPressure, maxPressure] = [40, 70];
            } else if (tireWidthMM < 45) {
                [minPressure, maxPressure] = [30, 55];
            } else {
                [minPressure, maxPressure] = [20, 45];
            }
        } else if (bikeType === 'mountainXC') {
            [minPressure, maxPressure] = [22, 35];
        } else if (bikeType === 'mountainTrail') {
            [minPressure, maxPressure] = [20, 32];
        } else if (bikeType === 'mountainEnduro') {
            [minPressure, maxPressure] = [18, 30];
        } else if (bikeType === 'fat') {
            [minPressure, maxPressure] = [5, 15];
        }
        
        return Math.max(minPressure, Math.min(maxPressure, pressure));
    },
    
    // Measured tire width grows ~0.4mm per 1mm of internal rim width
    // above the 19mm reference
    effectiveTireWidth(labeledWidthMM, internalRimWidthMM = null) {
        if (internalRimWidthMM === null) return labeledWidthMM;
        const delta = (internalRimWidthMM - 19.0) * 0.4;
        return Math.max(labeledWidthMM * 0.8, labeledWidthMM + delta);
    },
    
    calculate(riderWeightKg, bikeType, tireWidthMM, terrain, casing, ridingStyle, temperatureCelsius = null, rimType = 'hooked', internalRimWidthMM = null) {
        const warnings = [];
        const effectiveWidthMM = this.effectiveTireWidth(tireWidthMM, internalRimWidthMM);
        
        const bikeWeightKg = this.bikeTypes[bikeType].weight;
        const totalWeightKg = riderWeightKg + bikeWeightKg;
        const totalWeightLbs = totalWeightKg * 2.20462;
        
        const distribution = this.bikeTypes[bikeType].distribution;
        const frontWeightLbs = totalWeightLbs * distribution.front;
        const rearWeightLbs = totalWeightLbs * distribution.rear;
        
        let frontPressure = this.calculateBasePressure(frontWeightLbs, effectiveWidthMM, bikeType);
        let rearPressure = this.calculateBasePressure(rearWeightLbs, effectiveWidthMM, bikeType);
        
        const terrainMultiplier = this.terrainMultipliers[terrain];
        frontPressure *= terrainMultiplier;
        rearPressure *= terrainMultiplier;
        
        const casingAdjustment = this.casingAdjustments[casing];
        frontPressure += casingAdjustment;
        rearPressure += casingAdjustment;
        
        const styleAdjustment = this.ridingStyleAdjustments[ridingStyle];
        frontPressure += styleAdjustment;
        rearPressure += styleAdjustment;
        
        if (temperatureCelsius !== null) {
            const baseTemp = 20.0;
            const tempDiff = temperatureCelsius - baseTemp;
            const tempAdjustment = tempDiff * 0.15;
            frontPressure += tempAdjustment;
            rearPressure += tempAdjustment;
        }
        
        frontPressure = this.clampPressure(frontPressure, effectiveWidthMM, bikeType);
        rearPressure = this.clampPressure(rearPressure, effectiveWidthMM, bikeType);
        
        // Hookless rims: hard safety cap (ETRTO 5 bar / 72.5 psi)
        if (rimType === 'hookless') {
            const hooklessCap = 72.5;
            if (frontPressure > hooklessCap || rearPressure > hooklessCap) {
                warnings.push('Pressure capped at 72.5 psi: hookless rims must never exceed 72.5 psi (ETRTO). Consider a wider tire.');
            }
            frontPressure = Math.min(frontPressure, hooklessCap);
            rearPressure = Math.min(rearPressure, hooklessCap);
            
            if (tireWidthMM < 28) {
                warnings.push('Tires narrower than 28mm are not recommended on hookless rims.');
            }
        }
        
        frontPressure = Math.round(frontPressure * 2) / 2;
        rearPressure = Math.round(rearPressure * 2) / 2;
        
        return {
            frontPSI: frontPressure,
            rearPSI: rearPressure,
            frontBAR: frontPressure / 14.5038,
            rearBAR: rearPressure / 14.5038,
            warnings
        };
    }
};

// Test scenarios
const scenarios = [
    {
        name: "Classic Road Setup - 70kg rider, 28mm tires",
        params: {
            riderWeightKg: 70,
            bikeType: 'road',
            tireWidthMM: 28,
            terrain: 'smooth',
            casing: 'standard',
            ridingStyle: 'balanced'
        }
    },
    {
        name: "Gravel Adventure - 75kg rider, 40mm tires, rough gravel",
        params: {
            riderWeightKg: 75,
            bikeType: 'gravel',
            tireWidthMM: 40,
            terrain: 'gravel2',
            casing: 'standard',
            ridingStyle: 'balanced'
        }
    },
    {
        name: "Mountain Trail - 80kg rider, 2.4\" (61mm) tires",
        params: {
            riderWeightKg: 80,
            bikeType: 'mountainTrail',
            tireWidthMM: 61,
            terrain: 'trail',
            casing: 'standard',
            ridingStyle: 'balanced'
        }
    },
    {
        name: "Fast Road Racer - 65kg, 25mm tires, performance setup",
        params: {
            riderWeightKg: 65,
            bikeType: 'road',
            tireWidthMM: 25,
            terrain: 'smooth',
            casing: 'supple',
            ridingStyle: 'performance'
        }
    },
    {
        name: "Comfort Touring - 85kg, 32mm tires, comfort priority",
        params: {
            riderWeightKg: 85,
            bikeType: 'road',
            tireWidthMM: 32,
            terrain: 'mixed',
            casing: 'reinforced',
            ridingStyle: 'comfort'
        }
    },
    {
        name: "Cold Weather Gravel - 70kg, 38mm, 5°C",
        params: {
            riderWeightKg: 70,
            bikeType: 'gravel',
            tireWidthMM: 38,
            terrain: 'gravel2',
            casing: 'standard',
            ridingStyle: 'balanced',
            temperatureCelsius: 5
        }
    },
    {
        name: "Hot Summer Road - 70kg, 28mm, 35°C",
        params: {
            riderWeightKg: 70,
            bikeType: 'road',
            tireWidthMM: 28,
            terrain: 'smooth',
            casing: 'standard',
            ridingStyle: 'balanced',
            temperatureCelsius: 35
        }
    },
    {
        name: "Technical XC Race - 68kg, 2.25\" (57mm), technical terrain",
        params: {
            riderWeightKg: 68,
            bikeType: 'mountainXC',
            tireWidthMM: 57,
            terrain: 'technical',
            casing: 'supple',
            ridingStyle: 'performance'
        }
    },
    {
        name: "Fat Bike Snow - 90kg, 4.0\" (102mm) tires",
        params: {
            riderWeightKg: 90,
            bikeType: 'fat',
            tireWidthMM: 102,
            terrain: 'trail',
            casing: 'standard',
            ridingStyle: 'balanced',
            temperatureCelsius: -5
        }
    },
    {
        name: "Lightweight Climber - 55kg, 25mm, performance",
        params: {
            riderWeightKg: 55,
            bikeType: 'road',
            tireWidthMM: 25,
            terrain: 'smooth',
            casing: 'supple',
            ridingStyle: 'performance'
        }
    }
];

console.log('\n🚴 SPINMIN TIRE PRESSURE CALCULATIONS\n');
console.log('━'.repeat(80) + '\n');

scenarios.forEach((scenario, index) => {
    const result = TirePressureCalculator.calculate(
        scenario.params.riderWeightKg,
        scenario.params.bikeType,
        scenario.params.tireWidthMM,
        scenario.params.terrain,
        scenario.params.casing,
        scenario.params.ridingStyle,
        scenario.params.temperatureCelsius
    );
    
    console.log(`${index + 1}. ${scenario.name}`);
    console.log(`   Setup: ${scenario.params.riderWeightKg}kg rider, ${scenario.params.tireWidthMM}mm tires`);
    console.log(`   Conditions: ${scenario.params.terrain}, ${scenario.params.casing} casing, ${scenario.params.ridingStyle} style`);
    if (scenario.params.temperatureCelsius !== undefined) {
        console.log(`   Temperature: ${scenario.params.temperatureCelsius}°C`);
    }
    console.log(`   → FRONT: ${result.frontPSI.toFixed(1)} PSI (${result.frontBAR.toFixed(2)} BAR)`);
    console.log(`   → REAR:  ${result.rearPSI.toFixed(1)} PSI (${result.rearBAR.toFixed(2)} BAR)`);
    console.log('');
});

console.log('━'.repeat(80));
console.log('\n💡 All pressures are starting recommendations.');
console.log('   Fine-tune based on personal preference and tire/rim specs.\n');
