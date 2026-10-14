.pragma library
.import "RealLinearApi.js" as Real

var bootstrapQuery = Real.bootstrapQuery;
var issuesQuery = Real.issuesQuery;
var parentQuery = Real.parentQuery;
var updateMutation = Real.updateMutation;
var pending = [];
var history = [];
var nextError = "";
function reset() { pending = []; history = []; nextError = ""; }
function validPage(value) { return Real.validPage(value); }
function validIssue(value) { return Real.validIssue(value); }
function isDone(issue) { return Real.isDone(issue); }
function treeRows(issues, key, collapsed) { return Real.treeRows(issues, key, collapsed); }
function request(key, query, variables, callback) {
    var call = { key: key, query: query, variables: variables, callback: callback, canceled: false };
    history.push(call);
    if (nextError) {
        var error = nextError;
        nextError = "";
        callback(null, error);
    } else {
        pending.push(call);
    }
    return { cancel: function () { call.canceled = true; } };
}
// Deliberately deliver canceled requests too: daemon generation must guard them.
function complete(data, error) {
    if (!pending.length)
        throw new Error("No pending mocked request");
    pending.shift().callback(data, error || "");
}
