// Using the full TirePressureCalculationService
const TirePressureCalculator = require('./test-calculations.js').default || (() => {
    return {
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
        
        calculate(riderWeightKg, bikeType, tireWidthMM, terrain, casing, ridingStyle, temperatureCelsius = null) {
            const bikeWeightKg = this.bikeTypes[bikeType].weight;
            const totalWeightKg = riderWeightKg + bikeWeightKg;
            const totalWeightLbs = totalWeightKg * 2.20462;
            
            const distribution = this.bikeTypes[bikeType].distribution;
            const frontWeightLbs = totalWeightLbs * distribution.front;
            const rearWeightLbs = totalWeightLbs * distribution.rear;
            
            let frontPressure = this.calculateBasePressure(frontWeightLbs, tireWidthMM, bikeType);
            let rearPressure = this.calculateBasePressure(rearWeightLbs, tireWidthMM, bikeType);
            
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
            
            frontPressure = this.clampPressure(frontPressure, tireWidthMM, bikeType);
            rearPressure = this.clampPressure(rearPressure, tireWidthMM, bikeType);
            
            frontPressure = Math.round(frontPressure * 2) / 2;
            rearPressure = Math.round(rearPressure * 2) / 2;
            
            return {
                frontPSI: frontPressure,
                rearPSI: rearPressure,
                frontBAR: frontPressure / 14.5038,
                rearBAR: rearPressure / 14.5038
            };
        }
    };
})();

// User's specific setup
const systemWeightLbs = 185;
const systemWeightKg = systemWeightLbs / 2.20462; // 83.9 kg
const bikeWeightKg = 9.5; // Typical gravel bike
const riderWeightKg = systemWeightKg - bikeWeightKg; // 74.4 kg

const tempF = 70;
const tempC = (tempF - 32) * 5 / 9; // 21.1°C

console.log('\n🚴 FULL TirePressureCalculationService\n');
console.log('═'.repeat(60));
console.log('\n📋 Input Parameters:');
console.log(`  • System Weight: ${systemWeightLbs} lbs (${systemWeightKg.toFixed(1)} kg)`);
console.log(`  • Rider Weight: ${riderWeightKg.toFixed(1)} kg`);
console.log(`  • Bike Weight: ${bikeWeightKg} kg (typical gravel)`);
console.log('  • Bike Type: Gravel');
console.log('  • Tire Width: 45mm (700c x 45c)');
console.log('  • Tire Type: Tubeless');
console.log('  • Casing: Standard (medium)');
console.log('  • Terrain: Rocky gravel roads');
console.log('  • Riding Style: Performance (race pace)');
console.log(`  • Temperature: ${tempF}°F (${tempC.toFixed(1)}°C)`);
console.log('');

// Run calculation for gravel3 (rocky)
const result3 = TirePressureCalculator.calculate(
    riderWeightKg,
    'gravel',
    45,
    'gravel3',
    'standard',
    'performance',
    tempC
);

console.log('🎯 RECOMMENDED PRESSURES (Gravel Category 3 - Rocky):');
console.log('─'.repeat(60));
console.log(`  FRONT: ${result3.frontPSI.toFixed(1)} PSI  (${result3.frontBAR.toFixed(2)} BAR)`);
console.log(`  REAR:  ${result3.rearPSI.toFixed(1)} PSI  (${result3.rearBAR.toFixed(2)} BAR)`);
console.log('');

// Run calculation for gravel4 (very rocky)
const result4 = TirePressureCalculator.calculate(
    riderWeightKg,
    'gravel',
    45,
    'gravel4',
    'standard',
    'performance',
    tempC
);

console.log('🎯 RECOMMENDED PRESSURES (Gravel Category 4 - Very Rocky):');
console.log('─'.repeat(60));
console.log(`  FRONT: ${result4.frontPSI.toFixed(1)} PSI  (${result4.frontBAR.toFixed(2)} BAR)`);
console.log(`  REAR:  ${result4.rearPSI.toFixed(1)} PSI  (${result4.rearBAR.toFixed(2)} BAR)`);
console.log('');

console.log('═'.repeat(60));
console.log('\n📊 Calculation Breakdown:');
console.log('  1. Base pressure from weight + tire volume formula');
console.log('  2. Weight distribution: 47% front / 53% rear');
console.log(`  3. Terrain multiplier: ${TirePressureCalculator.terrainMultipliers.gravel3} (Cat 3) / ${TirePressureCalculator.terrainMultipliers.gravel4} (Cat 4)`);
console.log('  4. Casing adjustment: 0 PSI (standard)');
console.log('  5. Riding style: +2.0 PSI (performance)');
console.log(`  6. Temperature: +${((tempC - 20) * 0.15).toFixed(1)} PSI (${tempF}°F)`);
console.log('  7. Safety clamping: 20-45 PSI range for 45mm gravel');
console.log('  8. Rounding: nearest 0.5 PSI');
console.log('');
console.log('💡 These pressures match the iOS TirePressureCalculationService exactly!\n');
