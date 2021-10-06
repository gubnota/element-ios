// File created from FlowTemplate
// $ createRootCoordinator.sh TabBar TabBar
/*
 Copyright 2020 New Vector Ltd
 
 Licensed under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License.
 You may obtain a copy of the License at
 
 http://www.apache.org/licenses/LICENSE-2.0
 
 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 See the License for the specific language governing permissions and
 limitations under the License.
 */

import UIKit

@objcMembers
final class TabBarCoordinator: NSObject, TabBarCoordinatorType {
    
    // MARK: - Properties
    
    // MARK: Private
    
    private let parameters: TabBarCoordinatorParameters
    
    // Indicate if the Coordinator has started once
    private var hasStartedOnce: Bool {
        return self.masterTabBarController != nil
    }
    
    // TODO: Move MasterTabBarController navigation code here
    // and if possible use a simple: `private let tabBarController: UITabBarController`
    private var masterTabBarController: MasterTabBarController!
    
    // TODO: Embed UINavigationController in each tab like recommended by Apple and remove these properties. UITabBarViewController shoud not be embed in a UINavigationController (https://github.com/vector-im/riot-ios/issues/3086).
    private let navigationRouter: NavigationRouterType
    private let masterNavigationController: UINavigationController
    
    private var currentSpaceId: String?
    private var homeViewControllerWrapperViewController: HomeViewControllerWithBannerWrapperViewController?
    
    private var currentMatrixSession: MXSession? {
        return parameters.userSessionsService.mainUserSession?.matrixSession
    }
    
    private var isTabBarControllerTopMostController: Bool {
        return self.navigationRouter.modules.last is MasterTabBarController
    }
    
    // MARK: Public

    // Must be used only internally
    var childCoordinators: [Coordinator] = []
    
    weak var delegate: TabBarCoordinatorDelegate?
    
    weak var splitViewMasterPresentableDelegate: SplitViewMasterPresentableDelegate?
    
    // MARK: - Setup
        
    init(parameters: TabBarCoordinatorParameters) {
        self.parameters = parameters
        
        let masterNavigationController = RiotNavigationController()
        self.navigationRouter = NavigationRouter(navigationController: masterNavigationController)
        self.masterNavigationController = masterNavigationController
    }
    
    // MARK: - Public methods
    
    func start() {
        self.start(with: nil)
    }
        
    func start(with spaceId: String?) {
        self.currentSpaceId = spaceId
        
        // If start has been done once do not setup view controllers again
        if self.hasStartedOnce == false {
            let masterTabBarController = self.createMasterTabBarController()
            masterTabBarController.masterTabBarDelegate = self
            self.masterTabBarController = masterTabBarController
            self.navigationRouter.setRootModule(masterTabBarController)
            
            // Add existing Matrix sessions if any
            for userSession in self.parameters.userSessionsService.userSessions {
                self.addMatrixSessionToMasterTabBarController(userSession.matrixSession)
            }
            
            if BuildSettings.enableSideMenu {
                self.setupSideMenuGestures()
            }
            
            self.registerUserSessionsServiceNotifications()
            self.registerUserSessionsServiceNotifications()
            self.registerSessionChange()
            
            if let homeViewController = homeViewControllerWrapperViewController {
                let versionCheckCoordinator = VersionCheckCoordinator(rootViewController: masterTabBarController,
                                                                  bannerPresenter: homeViewController,
                                                                  themeService: ThemeService.shared())
                versionCheckCoordinator.start()
                add(childCoordinator: versionCheckCoordinator)
            }
        }
                
        self.updateMasterTabBarController(with: spaceId)
    }
    
    func toPresentable() -> UIViewController {
        return self.navigationRouter.toPresentable()
    }
    
    func releaseSelectedItems() {
        self.masterTabBarController.releaseSelectedItem()
    }
    
    func popToHome(animated: Bool, completion: (() -> Void)?) {
        
        // Force back to the main screen if this is not the one that is displayed
        if masterTabBarController != masterNavigationController.visibleViewController {
            
            // Listen to the masterNavigationController changes
            // We need to be sure that masterTabBarController is back to the screen
            
            let didPopToHome: (() -> Void) = {
                
                // For unknown reason, the navigation bar is not restored correctly by [popToViewController:animated:]
                // when a ViewController has hidden it (see MXKAttachmentsViewController).
                // Patch: restore navigation bar by default here.
                self.masterNavigationController.isNavigationBarHidden = false

                // Release the current selected item (room/contact/...).
                self.masterTabBarController.releaseSelectedItem()
                
                // Select home tab
                self.masterTabBarController.selectTab(at: .home)
                
                completion?()
            }

            // If MasterTabBarController is not visible because there is a modal above it
            // but still the top view controller of navigation controller
            if self.isTabBarControllerTopMostController {
                didPopToHome()
            } else {
                // Otherwise MasterTabBarController is not the top controller of the navigation controller
                
                // Waiting for `self.navigationRouter` popping to MasterTabBarController
                var token: NSObjectProtocol?
                token = NotificationCenter.default.addObserver(forName: NavigationRouter.didPopModule, object: self.navigationRouter, queue: OperationQueue.main) { [weak self] (notification) in
                    
                    guard let self = self else {
                        return
                    }
                    
                    // If MasterTabBarController is now the top most controller in navigation controller stack call the completion
                    if self.isTabBarControllerTopMostController {
                        
                        didPopToHome()
                        
                        if let token = token {
                            NotificationCenter.default.removeObserver(token)
                        }
                    }
                }
                
                // Pop to root view controller
                self.navigationRouter.popToRootModule(animated: animated)
            }
        } else {
            // Tab bar controller is already visible
            // Select the Home tab
            masterTabBarController.selectTab(at: .home)
            completion?()
        }
    }
    
    // MARK: - SplitViewMasterPresentable
    
    var selectedNavigationRouter: NavigationRouterType? {
        return self.navigationRouter
    }
    
    // MARK: - Private methods
    
    private func createMasterTabBarController() -> MasterTabBarController {
        let tabBarController = MasterTabBarController()
        
        if BuildSettings.enableSideMenu {
            let sideMenuBarButtonItem: MXKBarButtonItem = MXKBarButtonItem(image: Asset.Images.sideMenuIcon.image, style: .plain) { [weak self] in
                self?.showSideMenu()
            }
            sideMenuBarButtonItem.accessibilityLabel = VectorL10n.sideMenuRevealActionAccessibilityLabel
            
            tabBarController.navigationItem.leftBarButtonItem = sideMenuBarButtonItem
        } else {
            let settingsBarButtonItem: MXKBarButtonItem = MXKBarButtonItem(image: Asset.Images.settingsIcon.image, style: .plain) { [weak self] in
                self?.showSettings()
            }
            settingsBarButtonItem.accessibilityLabel = VectorL10n.settingsTitle
            
            tabBarController.navigationItem.leftBarButtonItem = settingsBarButtonItem
        }
        
        let searchBarButtonItem: MXKBarButtonItem = MXKBarButtonItem(image: Asset.Images.searchIcon.image, style: .plain) { [weak self] in
            self?.showUnifiedSearch()
        }
        searchBarButtonItem.accessibilityLabel = VectorL10n.searchDefaultPlaceholder
        
        tabBarController.navigationItem.rightBarButtonItem = searchBarButtonItem
        
        self.updateTabControllers(for: tabBarController, showCommunities: true)
        
        return tabBarController
    }
    
    private func createHomeViewController() -> UIViewController {
        let homeViewController: HomeViewController = HomeViewController.instantiate()
        homeViewController.tabBarItem.tag = Int(TABBAR_HOME_INDEX)
        homeViewController.tabBarItem.image = homeViewController.tabBarItem.image
        homeViewController.accessibilityLabel = VectorL10n.titleHome
        
        let wrapperViewController = HomeViewControllerWithBannerWrapperViewController(viewController: homeViewController)
        homeViewControllerWrapperViewController = wrapperViewController
        return wrapperViewController
    }
    
    private func createFavouritesViewController() -> FavouritesViewController {
        let favouritesViewController: FavouritesViewController = FavouritesViewController.instantiate()
        favouritesViewController.tabBarItem.tag = Int(TABBAR_FAVOURITES_INDEX)
        favouritesViewController.accessibilityLabel = VectorL10n.titleFavourites
        return favouritesViewController
    }
    
    private func createPeopleViewController() -> PeopleViewController {
        let peopleViewController: PeopleViewController = PeopleViewController.instantiate()
        peopleViewController.tabBarItem.tag = Int(TABBAR_PEOPLE_INDEX)
        peopleViewController.accessibilityLabel = VectorL10n.titlePeople
        return peopleViewController
    }
    
    private func createRoomsViewController() -> RoomsViewController {
        let roomsViewController: RoomsViewController = RoomsViewController.instantiate()
        roomsViewController.tabBarItem.tag = Int(TABBAR_ROOMS_INDEX)
        roomsViewController.accessibilityLabel = VectorL10n.titleRooms
        return roomsViewController
    }
    
    private func createGroupsViewController() -> GroupsViewController {
        let groupsViewController: GroupsViewController = GroupsViewController.instantiate()
        groupsViewController.tabBarItem.tag = Int(TABBAR_GROUPS_INDEX)
        groupsViewController.accessibilityLabel = VectorL10n.titleGroups
        return groupsViewController
    }
    
    private func createUnifiedSearchController() -> UnifiedSearchViewController {
        
        let viewController: UnifiedSearchViewController = UnifiedSearchViewController.instantiate()
        viewController.loadViewIfNeeded()
        
        for userSession in self.parameters.userSessionsService.userSessions {
            viewController.addMatrixSession(userSession.matrixSession)
        }
        
        return viewController
    }
    
    private func createSettingsViewController() -> SettingsViewController {
        let viewController: SettingsViewController = SettingsViewController.instantiate()
        viewController.loadViewIfNeeded()
        return viewController
    }
    
    private func setupSideMenuGestures() {
        let gesture = self.parameters.appNavigator.sideMenu.addScreenEdgePanGesturesToPresent(to: masterTabBarController.view)
        gesture.delegate = self
    }
    
    private func updateMasterTabBarController(with spaceId: String?) {
                
        self.updateTabControllers(for: self.masterTabBarController, showCommunities: spaceId == nil)
        self.masterTabBarController.filterRooms(withParentId: spaceId, inMatrixSession: self.currentMatrixSession)
    }
    
    private func updateTabControllers(for tabBarController: MasterTabBarController, showCommunities: Bool) {
        var viewControllers: [UIViewController] = []
                
        let homeViewController = self.createHomeViewController()
        viewControllers.append(homeViewController)
        
        if RiotSettings.shared.homeScreenShowFavouritesTab {
            let favouritesViewController = self.createFavouritesViewController()
            viewControllers.append(favouritesViewController)
        }
        
        if RiotSettings.shared.homeScreenShowPeopleTab {
            let peopleViewController = self.createPeopleViewController()
            viewControllers.append(peopleViewController)
        }
        
        if RiotSettings.shared.homeScreenShowRoomsTab {
            let roomsViewController = self.createRoomsViewController()
            viewControllers.append(roomsViewController)
        }
        
        if RiotSettings.shared.homeScreenShowCommunitiesTab && !(self.currentMatrixSession?.groups().isEmpty ?? false) && showCommunities {
            let groupsViewController = self.createGroupsViewController()
            viewControllers.append(groupsViewController)
        }
        
        tabBarController.updateViewControllers(viewControllers)
    }
    
    // MARK: Navigation
    
    private func showSideMenu() {
        self.parameters.appNavigator.sideMenu.show(from: self.masterTabBarController, animated: true)
    }
    
    private func dismissSideMenu(animated: Bool) {
        self.parameters.appNavigator.sideMenu.dismiss(animated: animated)
    }
    
    // FIXME: Should be displayed per tab.
    private func showSettings() {
        let viewController = self.createSettingsViewController()
        
        self.navigationRouter.push(viewController, animated: true, popCompletion: nil)
    }
    
    // FIXME: Should be displayed per tab.
    private func showUnifiedSearch() {
        let viewController = self.createUnifiedSearchController()
        
        self.navigationRouter.push(viewController, animated: true, popCompletion: nil)
    }
    
    // FIXME: Should be displayed from a tab.
    private func showContactDetails(with contact: MXKContact) {
        
        let coordinatorParameters = ContactDetailsCoordinatorParameters(contact: contact)
        let coordinator = ContactDetailsCoordinator(parameters: coordinatorParameters)
        coordinator.start()
        self.add(childCoordinator: coordinator)
        
        self.replaceSplitViewDetails(with: coordinator) {
            [weak self] in
            self?.remove(childCoordinator: coordinator)
        }
    }
    
    // FIXME: Should be displayed from a tab.
    private func showGroupDetails(with group: MXGroup, for matrixSession: MXSession) {
        let coordinatorParameters = GroupDetailsCoordinatorParameters(session: matrixSession, group: group)
        let coordinator = GroupDetailsCoordinator(parameters: coordinatorParameters)
        coordinator.start()
        self.add(childCoordinator: coordinator)
        
        self.replaceSplitViewDetails(with: coordinator) {
            [weak self] in
            self?.remove(childCoordinator: coordinator)
        }
    }
    
    private func showRoom(with roomId: String) {
        
        guard let matrixSession = self.parameters.userSessionsService.mainUserSession?.matrixSession else {
            return
        }
        
        self.showRoom(with: roomId, eventId: nil, matrixSession: matrixSession)
    }
    
    private func showRoom(with roomId: String, eventId: String?, matrixSession: MXSession, completion: (() -> Void)? = nil) {
        
        // RoomCoordinator will be presented by the split view
        // We don't which navigation controller instance will be used
        // Give the NavigationRouterStore instance and let it find the associated navigation controller if needed
        let roomCoordinatorParameters = RoomCoordinatorParameters(navigationRouterStore: NavigationRouterStore.shared, session: matrixSession, roomId: roomId, eventId: eventId)
        
        self.showRoom(with: roomCoordinatorParameters, completion: completion)
    }
    
    private func showRoomPreview(with previewData: RoomPreviewData) {
                
        // RoomCoordinator will be presented by the split view
        // We don't which navigation controller instance will be used
        // Give the NavigationRouterStore instance and let it find the associated navigation controller if needed
        let roomCoordinatorParameters = RoomCoordinatorParameters(navigationRouterStore: NavigationRouterStore.shared, previewData: previewData)
        
        self.showRoom(with: roomCoordinatorParameters)
    }
    
    private func showRoom(with parameters: RoomCoordinatorParameters, completion: (() -> Void)? = nil) {
        
        if let topRoomCoordinator =  self.splitViewMasterPresentableDelegate?.detailModules.last as? RoomCoordinatorProtocol,
           parameters.roomId == topRoomCoordinator.roomId && parameters.session == topRoomCoordinator.mxSession {
            
                // RoomCoordinator with the same room id and Matrix session is shown
            
                if let eventId = parameters.eventId {
                    // If there is an event id ask the RoomCoordinator to start with this one
                    topRoomCoordinator.start(withEventId: eventId, completion: completion)
                } else {
                    // If there is no event id defined do nothing
                    completion?()
                }
            return
        }
                        
        let coordinator = RoomCoordinator(parameters: parameters)
        coordinator.delegate = self
        coordinator.start(withCompletion: completion)
        self.add(childCoordinator: coordinator)
                
        self.replaceSplitViewDetails(with: coordinator) {
            [weak self] in
            // NOTE: The RoomDataSource releasing is handled in SplitViewCoordinator
            self?.remove(childCoordinator: coordinator)
        }
    }
    
    /// If the split view is collapsed (one column visible) it will push the Presentable on the primary navigation controller, otherwise it will show the Presentable as the secondary view of the split view.
    private func replaceSplitViewDetails(with presentable: Presentable, popCompletion: (() -> Void)? = nil) {
        self.splitViewMasterPresentableDelegate?.splitViewMasterPresentable(self, wantsToReplaceDetailWith: presentable, popCompletion: popCompletion)
    }
    
    // MARK: UserSessions management
    
    private func registerUserSessionsServiceNotifications() {
        
        // Listen only notifications from the current UserSessionsService instance
        let userSessionService = self.parameters.userSessionsService
        
        NotificationCenter.default.addObserver(self, selector: #selector(userSessionsServiceDidAddUserSession(_:)), name: UserSessionsService.didAddUserSession, object: userSessionService)
        
        NotificationCenter.default.addObserver(self, selector: #selector(userSessionsServiceWillRemoveUserSession(_:)), name: UserSessionsService.willRemoveUserSession, object: userSessionService)
    }
    
    @objc private func userSessionsServiceDidAddUserSession(_ notification: Notification) {
        guard let userSession = notification.userInfo?[UserSessionsService.NotificationUserInfoKey.userSession] as? UserSession else {
            return
        }
        
        self.addMatrixSessionToMasterTabBarController(userSession.matrixSession)
        
        if let matrixSession = self.currentMatrixSession, matrixSession.groups().isEmpty {
            self.masterTabBarController.removeTab(at: .groups)
        }
    }
    
    @objc private func userSessionsServiceWillRemoveUserSession(_ notification: Notification) {
        guard let userSession = notification.userInfo?[UserSessionsService.NotificationUserInfoKey.userSession] as? UserSession else {
            return
        }
        
        self.removeMatrixSessionFromMasterTabBarController(userSession.matrixSession)
    }
    
    // TODO: Remove Matrix session handling from the view controller
    private func addMatrixSessionToMasterTabBarController(_ matrixSession: MXSession) {
        MXLog.debug("[TabBarCoordinator] masterTabBarController.addMatrixSession")
        self.masterTabBarController.addMatrixSession(matrixSession)
    }
    
    // TODO: Remove Matrix session handling from the view controller
    private func removeMatrixSessionFromMasterTabBarController(_ matrixSession: MXSession) {
        MXLog.debug("[TabBarCoordinator] masterTabBarController.removeMatrixSession")
        self.masterTabBarController.removeMatrixSession(matrixSession)
    }
    
    private func registerSessionChange() {
        NotificationCenter.default.addObserver(self, selector: #selector(sessionDidSync(_:)), name: NSNotification.Name.mxSessionDidSync, object: nil)
    }
    
    @objc private func sessionDidSync(_ notification: Notification) {
        if self.currentMatrixSession?.groups().isEmpty ?? true {
            self.masterTabBarController.removeTab(at: .groups)
        }
    }
}

// MARK: - MasterTabBarControllerDelegate
extension TabBarCoordinator: MasterTabBarControllerDelegate {
        
    func masterTabBarController(_ masterTabBarController: MasterTabBarController!, didSelectRoomPreviewWith roomPreviewData: RoomPreviewData!) {
        self.showRoomPreview(with: roomPreviewData)
    }
    
    func masterTabBarController(_ masterTabBarController: MasterTabBarController!, didSelect contact: MXKContact!) {
        self.showContactDetails(with: contact)
    }
        
    func masterTabBarControllerDidCompleteAuthentication(_ masterTabBarController: MasterTabBarController!) {
        self.delegate?.tabBarCoordinatorDidCompleteAuthentication(self)
    }
    
    func masterTabBarController(_ masterTabBarController: MasterTabBarController!, didSelectRoomWithId roomId: String!, andEventId eventId: String!, inMatrixSession matrixSession: MXSession!, completion: (() -> Void)!) {
        self.showRoom(with: roomId, eventId: eventId, matrixSession: matrixSession, completion: completion)
    }
    
    func masterTabBarController(_ masterTabBarController: MasterTabBarController!, didSelect group: MXGroup!, inMatrixSession matrixSession: MXSession!) {
        self.showGroupDetails(with: group, for: matrixSession)
    }
    
    func masterTabBarController(_ masterTabBarController: MasterTabBarController!, needsSideMenuIconWithNotification displayNotification: Bool) {
        let image = displayNotification ? Asset.Images.sideMenuNotifIcon.image : Asset.Images.sideMenuIcon.image
        let sideMenuBarButtonItem: MXKBarButtonItem = MXKBarButtonItem(image: image, style: .plain) { [weak self] in
            self?.showSideMenu()
        }
        sideMenuBarButtonItem.accessibilityLabel = VectorL10n.sideMenuRevealActionAccessibilityLabel
        
        self.masterTabBarController.navigationItem.leftBarButtonItem = sideMenuBarButtonItem
    }
}

// MARK: - RoomCoordinatorDelegate
extension TabBarCoordinator: RoomCoordinatorDelegate {
    
    func roomCoordinatorDidDismissInteractively(_ coordinator: RoomCoordinatorProtocol) {
        self.remove(childCoordinator: coordinator)
    }
        
    func roomCoordinatorDidLeaveRoom(_ coordinator: RoomCoordinatorProtocol) {
        self.navigationRouter.popModule(animated: true)
    }
    
    func roomCoordinatorDidCancelRoomPreview(_ coordinator: RoomCoordinatorProtocol) {
        self.navigationRouter.popModule(animated: true)
    }
    
    func roomCoordinator(_ coordinator: RoomCoordinatorProtocol, didSelectRoomWithId roomId: String) {
        self.showRoom(with: roomId)
    }
}

// MARK: - UIGestureRecognizerDelegate

/**
 Prevent the side menu gesture from clashing with other gestures like the home screen horizontal scroll views.
 Also make sure that it doesn't cancel out UINavigationController backwards swiping
 */
extension TabBarCoordinator: UIGestureRecognizerDelegate {
    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRequireFailureOf otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return false
    }
    
    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldBeRequiredToFailBy otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
    
    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        if otherGestureRecognizer.isKind(of: UIScreenEdgePanGestureRecognizer.self) {
            return false
        } else {
            return true
        }
    }
}
