// 
// Copyright 2021 New Vector Ltd
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//

import AnalyticsEvents

/// A tappable UI element that can be tracked in Analytics.
@objc enum AnalyticsUIElement: Int {
    case roomThreadListButton
    case roomThreadSummaryItem
    case threadListThreadItem
    case threadListFilterItem
    case spacePanelSelectedSpace
    case spacePanelSwitchSpace
    
    /// The element name reported to the AnalyticsEvent.
    var name: AnalyticsEvent.Interaction.Name {
        switch self {
        case .roomThreadListButton:
            return .MobileRoomThreadListButton
        case .roomThreadSummaryItem:
            return .MobileRoomThreadSummaryItem
        case .threadListThreadItem:
            return .MobileThreadListThreadItem
        case .threadListFilterItem:
            return .MobileThreadListFilterItem
        case .spacePanelSelectedSpace:
            return .SpacePanelSelectedSpace
        case .spacePanelSwitchSpace:
            return .SpacePanelSwitchSpace
        }
    }
}
