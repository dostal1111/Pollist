import "dart:async";
import "dart:io";
import "dart:math" show Random;

import "package:redstone/server.dart" as Server;
import "package:redstone/server.dart" show Route, GET, POST, PUT, DELETE, ErrorResponse, Group, Interceptor, Attr;
import "package:redstone/query_map.dart";
import "package:redstone_mapper/mapper.dart";
import "package:redstone_mapper/plugin.dart";
import "package:redstone_mapper_mongo/manager.dart";
import "package:redstone_mapper_mongo/service.dart";
import "package:redstone_mapper_mongo/metadata.dart";

// TODO(kaendfinger): Need a way to prevent spamming.

final Random random = new Random();

MongoDbService<Poll> polls = new MongoDbService<Poll>("polls");
MongoDbService<PollResult> results = new MongoDbService<PollResult>("results");

class Poll extends Schema {
  @Id()
  String _objectId;
  
  @Field()
  String id;
  
  @Field()
  String title;
  
  @Field()
  List<String> choices;
}

class PollResult extends Schema {
  @Id()
  String _objectId;
  
  @Field()
  String poll;
  
  @Field()
  String id;
  
  @Field()
  int timestamp;
  
  @Field()
  String choice;
}

QueryMap<String, String> environment = new QueryMap<String, String>(Platform.environment);

main () {
  var host = [
    Platform.environment["POLLIST_HOST"],
    Platform.environment["C9_HOST"],
    "0.0.0.0"
  ].firstWhere((x) => x != null);
  
  var port = [
    int.parse(environment.get("POLLIST_PORT", ""), onError: (_) => null),
    int.parse(environment.get("C9_PORT", ""), onError: (_) => null),
    8080
  ].firstWhere((x) => x != null);
  
  var dbManager = new MongoDbManager("mongodb://localhost/pollist", poolSize: 3);
  
  Server.addPlugin(getMapperPlugin(dbManager));
  Server.setupConsoleLog();
  Server.start(address: host, port: port);
}

@Group("/api")
class ApiService {
  @Encode()
  @Route("/polls")
  listPolls() async => await polls.find();
  
  @Encode()
  @Route("/poll/:id")
  getPoll(String id) async {
    var poll = await polls.findOne({
      "id": id
    });
    
    if (poll == null) {
      throw new ErrorResponse(404, "Poll not found.");
    }
    
    return poll;
  }
  
  @Encode()
  @Route("/polls/create", methods: const [POST])
  createPoll(@Decode() Poll poll) async {
    var error = poll.validate();
    
    if (error != null) {
      throw new ErrorResponse(400, error.toString());
    }
    
    poll.id = generateBasicId(length: 20);
    await polls.insert(poll);
    return poll;
  }
  
  @Encode()
  @Route("/poll/:id/submit", methods: const [POST])
  submitPollResult(String id, @Decode() PollResult result) async {
    var poll = await getPoll(id);
    var error = result.validate();
    
    if (error != null) {
      throw new ErrorResponse(400, error.toString());
    }
    
    if (!poll.choices.contains(result.choice)) {
      throw new ErrorResponse(400, {
        "success": false,
        "error": "Invalid Choice: ${result.choice}"
      });
    }

    result.id = generateBasicId(length: 50);
    result.poll = poll.id;
    result.timestamp = new DateTime.now().millisecondsSinceEpoch;

    await results.insert(result);

    return result;
  }
  
  @Encode()
  @Route("/poll/:id/results")
  getPollResults(String id) async {
    var poll = await getPoll(id);
    
    return await results.find({
      "poll": poll.id
    });
  }
}

String generateBasicId({int length: 30}) {
  var r = new Random(random.nextInt(5000));
  var buffer = new StringBuffer();
  for (int i = 1; i <= length; i++) {
    var n = r.nextInt(50);
    if (n >= 0 && n <= 32) {
      String letter = alphabet[r.nextInt(alphabet.length)];
      buffer.write(r.nextBool() ? letter.toLowerCase() : letter);
    } else if (n > 32 && n <= 43) {
      buffer.write(numbers[r.nextInt(numbers.length)]);
    } else if (n > 43) {
      buffer.write(specials[r.nextInt(specials.length)]);
    }
  }
  return buffer.toString();
}

const List<String> alphabet = const [
  "A",
  "B",
  "C",
  "D",
  "E",
  "F",
  "G",
  "H",
  "I",
  "J",
  "K",
  "L",
  "M",
  "N",
  "O",
  "P",
  "Q",
  "R",
  "S",
  "T",
  "U",
  "V",
  "W",
  "X",
  "Y",
  "Z"
];

const List<int> numbers = const [
  0,
  1,
  2,
  3,
  4,
  5,
  6,
  7,
  8,
  9
];

const List<String> specials = const [
  "-"
];

@Interceptor("/.*", chainIdx: 1)
corsInterceptor() {
  const HEADERS = const {
    "Access-Control-Allow-Origin": "*"
  };
  
  if (Server.request.method == "OPTIONS") {
    var response = new shelf.Response.ok("", headers: HEADERS);
    Server.chain.interrupt(statusCode: HttpStatus.OK, responseValue: response);
  } else {
    Server.chain.next(() => Server.response.change(headers: HEADERS));
  }
}
