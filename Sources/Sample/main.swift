import Foundation
import GELF
import NIO

let group = MultiThreadedEventLoopGroup(numberOfThreads: 1)
let appender = GelfAppender(group: group,
        senderHost: "some-host", facility: "swift-gelf-test",
        host: "192.168.178.32")
try appender.start()

let logger = getLogger()
logger.info("Hello, world!")
logger.addAppender(appender)

for i in 1...100000 {
    logger.info("A first message: " + String(i), ["n": i])
}

sleep(60)

for i in 1...100000 {
    logger.info("A second message: " + String(i), ["n": i])
}

try appender.stop()
try group.syncShutdownGracefully()