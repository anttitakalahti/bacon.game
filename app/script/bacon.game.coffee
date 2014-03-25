Bacon = require("baconjs")
$ = require("jquery")
_ = require("lodash")

$.fn.asEventStream = Bacon.$.asEventStream

Bacon.Observable :: withTimestamp = ({ relative, precision } = { precision: 1 }) ->
  offset = if relative then new Date().getTime() else 0
  @flatMap (value) -> { value, timestamp: Math.floor((new Date().getTime() - offset) / precision) }

answerTemplate = "function answer($signature) {\n  $body\n}"

generateCode = (signature, body = "return Bacon.never()") ->
  answerTemplate.replace("$signature", signature).replace("$body", body)

assignments = [
  {
    description: "output value 1 immediately"
    example: "return Bacon.once(1)"
    signature: ""
    inputs: -> []
  }
  ,{
    description: "output value 'lol' after 1000 milliseconds",
    example: "return Bacon.later(1000, 'lol')",
    signature: ""
    inputs: -> []
  }
  ,{
    description: "Combine latest values of 2 inputs as array",
    example: "return Bacon.combineAsArray(a,b)",
    signature: "a, b"
    inputs: -> [Bacon.once("a"), Bacon.once("b")]
  }
].map (a, i) ->
  a.number = i+1
  a

presentAssignment = (assignment) ->
  $("#assignment .description").text(assignment.description)
  $("#assignment .number").text(assignment.number)
  $code = $("#assignment .code")
  $code.val(generateCode(assignment.signature))
  codeP = $code.asEventStream("input").merge(Bacon.once()).toProperty().map(-> $code.val())

  evalE = codeP.sampledBy($("#assignment .run").asEventStream("click").doAction(".preventDefault"))

  resultE = evalE.flatMap (code) ->
    showResult "running..."
    evaluateAssignment assignment, code

  resultE.map((x) -> if x then "Success!" else "FAIL").onValue(showResult)

showResult =  (result) ->
  $("#assignment .result").text(result)

evaluateAssignment = (assignment, code) ->
  actual = evalCode(code)(assignment.inputs() ...)
  expected = evalCode(generateCode(assignment.signature, assignment.example))(assignment.inputs() ...)

  actualValues = timestampedValues actual
  expectedValues = timestampedValues expected

  comparableValues = Bacon.combineTemplate
    actual: foldValues(actualValues)
    expected: foldValues(expectedValues)

  success = comparableValues.map ({actual, expected}) ->
    _.isEqual(actual, expected)

  success

timestampedValues = (src) ->
  src.withTimestamp({relative:true, precision: 100})

foldValues = (src) ->
  src.fold([], (values, value) -> values.concat(value))

collectAndVisualize = (src, values, desc) -> 
  src.withTimestamp({relative:true, precision: 100}).onValue (value) ->
    values.push(value)
    console.log(desc, value)

evalCode = (code) -> eval("(" + code + ")")

currentAssignmentIndex = $("#assignment .previous").asEventStream("click").map(-1)
  .merge($("#assignment .next").asEventStream("click").map(1))
  .scan(0, (num, diff) -> Math.min(assignments.length - 1, Math.max(0, num + diff)))
  .skipDuplicates()

currentAssignment = currentAssignmentIndex
  .map((i) -> assignments[i])

currentAssignment.onValue presentAssignment
