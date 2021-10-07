// File created from SimpleUserProfileExample
// $ createScreen.sh Room/UserSuggestion UserSuggestion
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

import Foundation
import Combine

@available(iOS 14.0, *)
struct RoomMembersProviderMember {
    var userId: String
    var displayName: String
    var avatarUrl: String
}

@available(iOS 14.0, *)
protocol RoomMembersProviderProtocol {
    func fetchMembers(_ members: @escaping ([RoomMembersProviderMember]) -> Void)
}

@available(iOS 14.0, *)
struct UserSuggestionServiceItem: UserSuggestionItemProtocol {
    let userId: String
    let displayName: String?
    let avatarUrl: String?
}

@available(iOS 14.0, *)
class UserSuggestionService: UserSuggestionServiceProtocol {
    
    // MARK: - Properties
    
    // MARK: Private
    
    private let roomMembersProvider: RoomMembersProviderProtocol
    
    private var suggestionItems: [UserSuggestionItemProtocol] = []
    private let currentTextTriggerSubject = CurrentValueSubject<String?, Never>(nil)
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: Public
    
    var items = CurrentValueSubject<[UserSuggestionItemProtocol], Never>([])
    
    var currentTextTrigger: String? {
        currentTextTriggerSubject.value
    }
    
    // MARK: - Setup
    
    init(roomMembersProvider: RoomMembersProviderProtocol) {
        self.roomMembersProvider = roomMembersProvider
        
        currentTextTriggerSubject
            .removeDuplicates()
            .debounce(for: 0.5, scheduler: RunLoop.main)
            .sink { self.fetchAndFilterMembersForTextTrigger($0) }
            .store(in: &cancellables)
    }
    
    // MARK: - UserSuggestionServiceProtocol
    
    func processTextMessage(_ textMessage: String?) {
        self.items.send([])
        self.currentTextTriggerSubject.send(nil)
        
        guard let textMessage = textMessage, textMessage.count > 0 else {
            return
        }
        
        let components = textMessage.components(separatedBy: .whitespaces)
        
        guard let lastComponent = components.last else {
            return
        }
        
        // Partial username should start with one and only one "@" character
        guard lastComponent.prefix(while: { $0 == "@" }).count == 1 else {
            return
        }
        
        self.currentTextTriggerSubject.send(lastComponent)
    }
    
    // MARK: - Private
    
    private func fetchAndFilterMembersForTextTrigger(_ textTrigger: String?) {
        guard var partialName = textTrigger else {
            return
        }
        
        partialName.removeFirst() // remove the '@' prefix
        
        roomMembersProvider.fetchMembers { [weak self] members in
            guard let self = self else {
                return
            }
            
            self.suggestionItems = members.map { member in
                UserSuggestionServiceItem(userId: member.userId, displayName: member.displayName, avatarUrl: member.avatarUrl)
            }
            
            self.items.send(self.suggestionItems.filter({ userSuggestion in
                let containedInUsername = userSuggestion.userId.lowercased().contains(partialName.lowercased())
                let containedInDisplayName = (userSuggestion.displayName ?? "").lowercased().contains(partialName.lowercased())
                
                return (containedInUsername || containedInDisplayName)
            }))
        }
    }
}
