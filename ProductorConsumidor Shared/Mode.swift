//
//  Mode.swift
//  ProductorConsumidor
//
//  Created by Diego on 23/8/25.
//


//
//  Mode.swift
//  PrototipoSO
//
//  Created by Diego on 20/8/25.
//


// Mode.swift
import Foundation

enum Mode { case employees, manual }

extension Mode {
    var text: String { self == .employees ? "Empleados" : "Manual" }
}
