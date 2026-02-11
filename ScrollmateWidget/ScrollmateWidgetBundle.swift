//
//  ScrollmateWidgetBundle.swift
//  ScrollmateWidget
//
//  Created by 김석현 on 2/11/26.
//

import WidgetKit
import SwiftUI

@main
struct ScrollmateWidgetBundle: WidgetBundle {
    var body: some Widget {
        ScrollmateWidget()
        ScrollmateWidgetLiveActivity()
    }
}
