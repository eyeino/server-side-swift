import Cryptor
import Foundation
import Kitura
import KituraNet
import HeliumLogger
import LoggerAPI
import MySQL
import SwiftyJSON

func connectToDatabase() throws -> (Database, Connection) {
    let mysql = try Database(
        host: "localhost",
        user: "swift",
        password: "swift",
        database: "swift"
    )

    let connection = try mysql.makeConnection()
    return (mysql, connection)
}

HeliumLogger.use()
let router = Router()
router.post("/", middleware: BodyParser())

router.get("/:user/posts") {
    request, response, next in
    defer { next() }

    // 1. Figure out which user to load
    guard let user = request.parameters["user"] else { return }

    // 2. Connect to MySQL
    let (db, connection) = try connectToDatabase()

    // 3. Create a query string with gaps in
    let query = "SELECT `id`, `user`, `message`, `date` FROM `posts` WHERE `user` = ? ORDER BY `date` DESC;"

    // 4. Merge the query string with our parameter
    let posts = try db.execute(query, [user], connection)

    // 5. Convert the result into dictionaries
    var parsedPosts = [[String: Any]]()

    for post in posts {
        var postDictionary = [String: Any]()
        postDictionary["id"] = post["id"]?.int
        postDictionary["user"] = post["user"]?.string
        postDictionary["message"] = post["message"]?.string
        postDictionary["date"] = post["date"]?.string
        parsedPosts.append(postDictionary)
    }

    var result = [String: Any]()
    result["status"] = "ok"
    result["posts"] = parsedPosts

    // 6. Convert the response to JSON and send it out
    let json = JSON(result)

    do {
        try response.status(.OK).send(json: json).end()
    } catch {
        Log.warning("Failed to send /:user/posts for \(user): \(error.localizedDescription)")
    }
}

Kitura.addHTTPServer(onPort: 8090, with: router)
Kitura.run()