//
//  SensorCatalog.swift
//  fanny-macOS
//
//  Created by Daniel Storm on 11/25/26.
//  Copyright © 2026 Daniel Storm. All rights reserved.
//

import Foundation

/// Every CPU and GPU temperature key Fanny can read on some Apple silicon Mac, for the Developer Menu's sensor tables.
/// - Note: Covers M1 through M6. Keys a Mac lists beyond these are added when the tables load.
enum SensorCatalog {
    
    static let cpuKeyNames: [String] = SensorCatalog.keyNames("""
        TCMb TCMz Te00 Te01 Te02 Te04 Te05 Te06 Te07 Te08 Te09 Te0A Te0C Te0G Te0H Te0I
        Te0K Te0L Te0M Te0O Te0P Te0Q Te0R Te0S Te0T Te0U Te0V Te0W Te0X Te0a Te0b Te0c
        Te0h Te0i Te0x Te0z Te20 Te21 Te3a Te3b Te3x Te3z Tex0 Tex1 Tex2 Tex3 Tf04 Tf09
        Tf0A Tf0B Tf0D Tf0E Tf44 Tf49 Tf4A Tf4B Tf4D Tf4E Tm00 Tm04 Tm08 Tm0C Tm0G Tm0K
        Tm0O Tm0R Tm0U Tm0X Tm0a Tm0d Tm0g Tm0j Tm0m Tm0p Tm0u Tm1E Tm1I Tm1M Tm1Q Tm1U
        Tm1Y Tm1c Tm1g Tm1k Tm1o Tm1s Tm1x Tm21 Tm25 Tm29 Tm2D Tm2H Tm2L Tm2P Tm2j Tm2n
        Tp00 Tp01 Tp02 Tp04 Tp05 Tp06 Tp07 Tp08 Tp09 Tp0A Tp0C Tp0D Tp0E Tp0G Tp0H Tp0I
        Tp0K Tp0L Tp0M Tp0O Tp0P Tp0Q Tp0R Tp0S Tp0T Tp0U Tp0V Tp0W Tp0X Tp0Y Tp0Z Tp0a
        Tp0b Tp0c Tp0d Tp0e Tp0f Tp0g Tp0h Tp0i Tp0j Tp0k Tp0l Tp0m Tp0n Tp0o Tp0p Tp0q
        Tp0r Tp0s Tp0t Tp0u Tp0v Tp0w Tp0y Tp0z Tp10 Tp12 Tp13 Tp14 Tp16 Tp17 Tp18 Tp1A
        Tp1B Tp1C Tp1E Tp1F Tp1G Tp1H Tp1I Tp1J Tp1K Tp1L Tp1M Tp1N Tp1O Tp1Q Tp1R Tp1S
        Tp1U Tp1g Tp1h Tp1i Tp1j Tp1k Tp1l Tp1m Tp1n Tp1o Tp1p Tp1q Tp1s Tp1t Tp1u Tp1v
        Tp1w Tp1x Tp1y Tp1z Tp20 Tp21 Tp22 Tp23 Tp24 Tp25 Tp26 Tp27 Tp28 Tp29 Tp2A Tp2B
        Tp2C Tp2D Tp2E Tp2G Tp2H Tp2I Tp2J Tp2K Tp2L Tp2M Tp2N Tp2O Tp2P Tp2Q Tp2R Tp2S
        Tp2T Tp2U Tp2V Tp2W Tp2X Tp2Y Tp2a Tp2b Tp2c Tp2x Tp2z Tp3O Tp3P Tp3S Tp3T Tp3W
        Tp3X Tp3a Tp3b Tp3x Tp3z Tp4a Tp4b Tp4x Tp4z Tp5a Tp5b Tp5x Tp5z Tp7a Tp7b Tp7x
        Tp7z Tp8a Tp8b Tp8x Tp8z Tp9a Tp9b Tp9x Tp9z Tpx0 Tpx1 Tpx2 Tpx3 Tpx4 Tpx5 Tpx8
        Tpx9 TpxA TpxB TpxC TpxD
        """)
    
    static let gpuKeyNames: [String] = SensorCatalog.keyNames("""
        Tf14 Tf18 Tf19 Tf1A Tf24 Tf28 Tf29 Tf2A Tg00 Tg01 Tg04 Tg05 Tg07 Tg08 Tg09 Tg0C
        Tg0D Tg0G Tg0H Tg0K Tg0L Tg0O Tg0P Tg0R Tg0S Tg0T Tg0U Tg0V Tg0W Tg0X Tg0Y Tg0a
        Tg0b Tg0c Tg0d Tg0e Tg0f Tg0g Tg0i Tg0j Tg0k Tg0m Tg0n Tg0p Tg0q Tg0r Tg0u Tg0v
        Tg0y Tg0z Tg12 Tg13 Tg16 Tg17 Tg1A Tg1B Tg1E Tg1F Tg1I Tg1M Tg1Q Tg1U Tg1V Tg1Y
        Tg1b Tg1c Tg1d Tg1e Tg1f Tg1g Tg1h Tg1k Tg1l Tg1o Tg1s Tg1t Tg1x Tg1y Tg21 Tg22
        Tg29 Tg2A Tg2D Tg2H Tg2I Tg2P Tg2Q Tg2T Tg2W Tg2X Tg2Y Tg2b Tg2e Tg2f Tg2g Tg2j
        Tg2n Tg2o Tg2r Tg33 Tg34 Tg3B Tg3C Tg3F Tg3J Tg3K Tg3R Tg3V Tg3Y Tg3Z Tg3a Tg3d
        Tg3h Tg3i Tg3l Tg3p Tg3q Tg3t Tg3x Tg3y Tg43 Tg4D Tg4G Tg4P Tg4S Tg4V Tg4Y Tg4b
        Tg4e Tg4h Tg4k Tg50 Tg53 Tg5C Tg5F Tg5I Tg5L Tg5O Tg5R Tg5Y Tg5b Tg5h Tg5q Tg5t
        Tg63 Tg66 Tg69 Tg6C Tg6F Tg6I Tg6L Tg6O Tg6e Tg6h Tg6q Tg6t Tg6w Tg70 Tg73 Tg76
        Tg7C Tg7F Tg7L
        """)
    
    // MARK: - Names
    /// Such as "Te05 (CPU Efficiency Core)".
    static func title(forKeyName name: String) -> String {
        return "\(name) (\(displayName(forKeyName: name)))"
    }
    
    private static func displayName(forKeyName name: String) -> String {
        let displayName: String
        
        if name == "TCMb" {
            displayName = String(localized: "CPU Die", comment: "Developer Menu: name of the CPU die key, as in TCMb (CPU Die).")
        }
        else if name == "TCMz" {
            displayName = String(localized: "CPU Die Max", comment: "Developer Menu: name of the hottest CPU die key, as in TCMz (CPU Die Max).")
        }
        else if name.hasPrefix("Tp") {
            displayName = String(localized: "CPU Core", comment: "Developer Menu: name of a CPU performance core key, as in Tp01 (CPU Core).")
        }
        else if name.hasPrefix("Te") {
            displayName = String(localized: "CPU Efficiency Core", comment: "Developer Menu: name of a CPU efficiency core key, as in Te05 (CPU Efficiency Core).")
        }
        // CPU clusters on M5 Pro and Max, memory on other chips.
        else if name.hasPrefix("Tm") {
            displayName = String(localized: "CPU Cluster or Memory", comment: "Developer Menu: name of a key that is a CPU cluster on some chips and memory on others.")
        }
        else if name.hasPrefix("Tg") {
            displayName = String(localized: "GPU", comment: "Developer Menu: name of a GPU key, as in Tg0f (GPU).")
        }
        else if TemperatureSelector.isGPUKey(name) {
            displayName = String(localized: "GPU Fallback", comment: "Developer Menu: name of a GPU key read only when no main GPU key is live.")
        }
        else {
            displayName = String(localized: "CPU Cluster Fallback", comment: "Developer Menu: name of a CPU cluster key read only when no core key is live.")
        }
        
        return displayName
    }
    
    // MARK: - Helpers
    private static func keyNames(_ list: String) -> [String] {
        return list.split(whereSeparator: { $0.isWhitespace }).map({ String($0) })
    }
}
