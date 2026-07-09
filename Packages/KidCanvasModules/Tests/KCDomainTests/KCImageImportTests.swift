//
//  KCImageImportTests.swift
//  KCDomainTests
//
//  Created by 小大 on 2026/07/09.
//

import XCTest
@testable import KCDomain

final class KCImageImportTests: XCTestCase {

    // MARK: - 相机

    func testCameraUnavailableShowsNoCameraFallback() {
        // 模拟器/无相机设备：相机来源不可用 → 降级提示（保留相册路径）。
        let action = KCImageImportDecision.resolve(source: .camera, isAvailable: false, authorization: .authorized)
        XCTAssertEqual(action, .showNoCamera)
    }

    func testCameraDeniedShowsCameraDeniedFailure() {
        let action = KCImageImportDecision.resolve(source: .camera, isAvailable: true, authorization: .denied)
        XCTAssertEqual(action, .showDeniedFailure(.cameraDenied))
    }

    func testCameraNotDeterminedRequestsAuthorization() {
        let action = KCImageImportDecision.resolve(source: .camera, isAvailable: true, authorization: .notDetermined)
        XCTAssertEqual(action, .requestAuthorization)
    }

    func testCameraAuthorizedPresents() {
        let action = KCImageImportDecision.resolve(source: .camera, isAvailable: true, authorization: .authorized)
        XCTAssertEqual(action, .present)
    }

    // MARK: - 相册

    func testPhotoLibraryDeniedShowsPhotoLibraryDeniedFailure() {
        let action = KCImageImportDecision.resolve(source: .photoLibrary, isAvailable: true, authorization: .denied)
        XCTAssertEqual(action, .showDeniedFailure(.photoLibraryDenied))
    }

    func testPhotoLibraryNotDeterminedRequestsAuthorization() {
        let action = KCImageImportDecision.resolve(source: .photoLibrary, isAvailable: true, authorization: .notDetermined)
        XCTAssertEqual(action, .requestAuthorization)
    }

    func testPhotoLibraryAuthorizedPresents() {
        let action = KCImageImportDecision.resolve(source: .photoLibrary, isAvailable: true, authorization: .authorized)
        XCTAssertEqual(action, .present)
    }

    func testPhotoLibraryUnavailableIsHardFailure() {
        // 相册来源不可用（极少数受限环境）属异常失败，不走 noCamera 分支。
        let action = KCImageImportDecision.resolve(source: .photoLibrary, isAvailable: false, authorization: .authorized)
        XCTAssertEqual(action, .showDeniedFailure(.failed))
    }

    // MARK: - 失败与来源稳定标识

    func testFailureRawValuesAreStable() {
        XCTAssertEqual(KCImageImportFailure.cameraDenied.rawValue, "cameraDenied")
        XCTAssertEqual(KCImageImportFailure.photoLibraryDenied.rawValue, "photoLibraryDenied")
        XCTAssertEqual(KCImageImportFailure.noCamera.rawValue, "noCamera")
    }

    func testSourceRawValuesAreStable() {
        XCTAssertEqual(KCImageImportSource.photoLibrary.rawValue, "photoLibrary")
        XCTAssertEqual(KCImageImportSource.camera.rawValue, "camera")
    }
}
