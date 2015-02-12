//
//  HeimdallSpec.swift
//  Heimdall
//
//  Created by Felix Jendrusch on 2/10/15.
//  Copyright (c) 2015 B264 GmbH. All rights reserved.
//

import AeroGearHttpStub
import Heimdall
import LlamaKit
import Nimble
import Quick

class MockAccessTokenStorage: AccessTokenStorage {
    var storeAccessTokenCalled: Bool = false

    var mockedAccessToken: AccessToken? = nil
    var storedAccessToken: AccessToken? = nil
    
    func storeAccessToken(accessToken: AccessToken?){
        storeAccessTokenCalled = true

        storedAccessToken = accessToken
    }
    
    func retrieveAccessToken() -> AccessToken? {
        return mockedAccessToken ?? storedAccessToken
    }
}

class HeimdallSpec: QuickSpec {
    let bundle = NSBundle(forClass: HeimdallSpec.self)

    override func spec() {
        var accessTokenStorage: MockAccessTokenStorage!
        var heimdall: Heimdall!

        beforeEach {
            accessTokenStorage = MockAccessTokenStorage()
            heimdall = Heimdall(tokenURL: NSURL(string: "http://rheinfabrik.de")!, accessTokenStorage: accessTokenStorage)
        }
        
        describe("-init") {
            context("when a token is saved in the storage") {
                it("loads the token from the token storage") {
                    accessTokenStorage.mockedAccessToken = AccessToken(accessToken: "foo", tokenType: "bar")
                    expect(heimdall.hasAccessToken).to(beTrue())
                }
            }
        }

        describe("-authorize") {
            var result: Result<Void, NSError>?

            afterEach {
                result = nil
            }

            context("with a valid response") {
                beforeEach {
                    StubsManager.stubRequestsPassingTest({ _ in true }) { request in
                        return StubResponse(filename: "authorize-valid.json", bundle: self.bundle)
                    }

                    waitUntil { done in
                        heimdall.authorize("username", password: "password") { result = $0; done() }
                    }
                }

                afterEach {
                    StubsManager.removeAllStubs()
                }

                it("succeeds") {
                    expect(result?.isSuccess).to(beTrue())
                }

                it("sets the access token") {
                    expect(accessTokenStorage.storeAccessTokenCalled).to(beTrue())
                }
                
                it("stores the access token in the token storage") {
                    expect(accessTokenStorage.storeAccessTokenCalled).to(beTrue())
                }
            }

            context("with an error response") {
                beforeEach {
                    StubsManager.stubRequestsPassingTest({ _ in true }) { request in
                        return StubResponse(filename: "authorize-error.json", bundle: self.bundle, statusCode: 400)
                    }

                    waitUntil { done in
                        heimdall.authorize("username", password: "password") { result = $0; done() }
                    }
                }

                afterEach {
                    StubsManager.removeAllStubs()
                }

                it("fails") {
                    expect(result?.isSuccess).to(beFalse())
                }

                it("fails with the correct error domain") {
                    expect(result?.error?.domain).to(equal(OAuthErrorDomain))
                }

                it("fails with the correct error code") {
                    expect(result?.error?.code).to(equal(OAuthErrorInvalidClient))
                }

                it("does not set the access token") {
                    expect(heimdall.hasAccessToken).to(beFalse())
                }
            }

            context("with an invalid response") {
                beforeEach {
                    StubsManager.stubRequestsPassingTest({ _ in true }) { request in
                        return StubResponse(filename: "authorize-invalid.json", bundle: self.bundle)
                    }

                    waitUntil { done in
                        heimdall.authorize("username", password: "password") { result = $0; done() }
                    }
                }

                afterEach {
                    StubsManager.removeAllStubs()
                }

                it("fails") {
                    expect(result?.isSuccess).to(beFalse())
                }

                it("fails with the correct error domain") {
                    expect(result?.error?.domain).to(equal(HeimdallErrorDomain))
                }

                it("fails with the correct error code") {
                    expect(result?.error?.code).to(equal(HeimdallErrorInvalidData))
                }

                it("does not set the access token") {
                    expect(heimdall.hasAccessToken).to(beFalse())
                }
            }

            context("with an invalid response missing a token") {
                beforeEach {
                    StubsManager.stubRequestsPassingTest({ _ in true }) { request in
                        return StubResponse(filename: "authorize-invalid-token.json", bundle: self.bundle)
                    }

                    waitUntil { done in
                        heimdall.authorize("username", password: "password") { result = $0; done() }
                    }
                }

                afterEach {
                    StubsManager.removeAllStubs()
                }

                it("fails") {
                    expect(result?.isSuccess).to(beFalse())
                }

                it("fails with the correct error domain") {
                    expect(result?.error?.domain).to(equal(HeimdallErrorDomain))
                }

                it("fails with the correct error code") {
                    expect(result?.error?.code).to(equal(HeimdallErrorInvalidData))
                }

                it("does not set the access token") {
                    expect(heimdall.hasAccessToken).to(beFalse())
                }
            }

            context("with an invalid response missing a type") {
                beforeEach {
                    StubsManager.stubRequestsPassingTest({ _ in true }) { request in
                        return StubResponse(filename: "authorize-invalid-type.json", bundle: self.bundle)
                    }

                    waitUntil { done in
                        heimdall.authorize("username", password: "password") { result = $0; done() }
                    }
                }

                afterEach {
                    StubsManager.removeAllStubs()
                }

                it("fails") {
                    expect(result?.isSuccess).to(beFalse())
                }

                it("fails with the correct error domain") {
                    expect(result?.error?.domain).to(equal(HeimdallErrorDomain))
                }

                it("fails with the correct error code") {
                    expect(result?.error?.code).to(equal(HeimdallErrorInvalidData))
                }

                it("does not set the access token") {
                    expect(heimdall.hasAccessToken).to(beFalse())
                }
            }
        }

        describe("-requestByAddingAuthorizationToRequest") {
            var request = NSURLRequest(URL: NSURL(string: "http://rheinfabrik.de")!)
            var result: Result<NSURLRequest, NSError>?

            afterEach {
                result = nil
            }

            context("when not authorized") {
                beforeEach {
                    waitUntil { done in
                        heimdall.requestByAddingAuthorizationToRequest(request) { result = $0; done() }
                    }
                }

                it("fails") {
                    expect(result?.isSuccess).to(beFalse())
                }

                it("fails with the correct error domain") {
                    expect(result?.error?.domain).to(equal(HeimdallErrorDomain))
                }

                it("fails with the correct error code") {
                    expect(result?.error?.code).to(equal(HeimdallErrorNotAuthorized))
                }
            }

            context("when authorized with a still valid access token") {
                beforeEach {
                    StubsManager.stubRequestsPassingTest({ _ in true }) { request in
                        return StubResponse(filename: "request-valid.json", bundle: self.bundle)
                    }

                    waitUntil { done in
                        heimdall.authorize("username", password: "password") { _ in done() }
                    }

                    waitUntil { done in
                        heimdall.requestByAddingAuthorizationToRequest(request) { result = $0; done() }
                    }
                }

                it("succeeds") {
                    expect(result?.isSuccess).to(beTrue())
                }

                it("adds the correct authorization header to the request") {
                    expect(result?.value?.HTTPAuthorization).to(equal("bearer MTQzM2U3YTI3YmQyOWQ5YzQ0NjY4YTZkYjM0MjczYmZhNWI1M2YxM2Y1MjgwYTg3NDk3ZDc4ZGUzM2YxZmJjZQ"))
                }
            }

            context("when authorized with an expired access token and no refresh token") {
                beforeEach {
                    StubsManager.stubRequestsPassingTest({ _ in true }) { request in
                        return StubResponse(filename: "request-invalid-norefresh.json", bundle: self.bundle)
                    }

                    waitUntil { done in
                        heimdall.authorize("username", password: "password") { _ in done() }
                    }

                    waitUntil { done in
                        heimdall.requestByAddingAuthorizationToRequest(request) { result = $0; done() }
                    }
                }

                it("fails") {
                    expect(result?.isSuccess).to(beFalse())
                }

                it("fails with the correct error domain") {
                    expect(result?.error?.domain).to(equal(HeimdallErrorDomain))
                }

                it("fails with the correct error code") {
                    expect(result?.error?.code).to(equal(HeimdallErrorNotAuthorized))
                }
            }

            context("when authorized with an expired access token and a valid refresh token") {
                beforeEach {
                    StubsManager.stubRequestsPassingTest({ _ in !heimdall.hasAccessToken }) { request in
                        return StubResponse(filename: "request-invalid.json", bundle: self.bundle)
                    }

                    waitUntil { done in
                        heimdall.authorize("username", password: "password") { _ in done() }
                    }

                    StubsManager.stubRequestsPassingTest({ _ in true }) { request in
                        return StubResponse(filename: "request-valid.json", bundle: self.bundle)
                    }

                    waitUntil { done in
                        heimdall.requestByAddingAuthorizationToRequest(request) { result = $0; done() }
                    }
                }

                it("succeeds") {
                    expect(result?.isSuccess).to(beTrue())
                }

                it("adds the correct authorization header to the request") {
                    expect(result?.value?.HTTPAuthorization).to(equal("bearer MTQzM2U3YTI3YmQyOWQ5YzQ0NjY4YTZkYjM0MjczYmZhNWI1M2YxM2Y1MjgwYTg3NDk3ZDc4ZGUzM2YxZmJjZQ"))
                }
            }
        }
    }
}
