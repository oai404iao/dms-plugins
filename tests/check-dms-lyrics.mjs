import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import vm from "node:vm";

const source = readFileSync(new URL("../plugins/lyrics/LyricsFetcher.js", import.meta.url), "utf8");

const catalog = JSON.parse(readFileSync(new URL("../plugins/lyrics/translations/zh_CN.json", import.meta.url), "utf8"));
const localizedFiles = [
    "../plugins/lyrics/LyricsSettings.qml",
    "../plugins/lyrics/LyricsService.qml",
    "../scripts/dms-media-lyrics/MediaPlayerDashChrome.qml",
];
const terms = new Set();
for (const path of localizedFiles) {
    const qml = readFileSync(new URL(path, import.meta.url), "utf8");
    assert.doesNotMatch(qml, /[\u3400-\u9fff]/u, "UI strings belong in the locale catalog");
    for (const match of qml.matchAll(/I18n\.trFor\("lyrics", "([^"]+)"\)/g))
        terms.add(match[1]);
}
assert.deepEqual(Object.keys(catalog).sort(), [...terms].sort(), "Chinese catalog must cover all plugin UI terms, without stale entries");
for (const term of terms) {
    assert.deepEqual(Object.keys(catalog[term]), [term]);
    assert.equal(typeof catalog[term][term], "string");
    assert.ok(catalog[term][term].trim());
    assert.ok(!catalog[term][term].includes(term), "Do not append English source text to the translation");
}

function fixture() {
    const requests = [];
    class FakeRequest {
        static DONE = 4;
        headers = {};
        open(method, url) {
            assert.equal(method, "GET");
            this.url = new URL(url);
        }
        setRequestHeader(name, value) {
            this.headers[name] = value;
        }
        send() {
            requests.push(this);
        }
        abort() {
            this.aborted = true;
            this.onerror();
        }
        reply(body, status = 200) {
            this.status = status;
            this.readyState = 4;
            this.responseText = typeof body === "string" ? body : JSON.stringify(body);
            this.onreadystatechange();
        }
    }
    const context = vm.createContext({ XMLHttpRequest: FakeRequest });
    vm.runInContext(source, context);
    return { api: context, requests };
}

const plain = value => JSON.parse(JSON.stringify(value));
const { api } = fixture();
assert.deepEqual(plain(api.parseLrc("[ar:example]\r\n[00:02.50]second\n[00:01.000][00:03.00]first\n[00:04.00]\n[00:70.00]invalid")), [
    { time: 1, text: "first" },
    { time: 2.5, text: "second" },
    { time: 3, text: "first" },
    { time: 4, text: "" },
]);
assert.deepEqual(plain(api.parseLrc(null)), []);
assert.deepEqual(plain(api.withTranslations(
    "[00:01]original one\n[00:02]original two\n[00:03]\n[00:04]same\n[00:05]original five\n[00:06]original six",
    "[00:01.10]译文一\n[00:03]不要用于空行\n[00:04]same\n[00:05]//\n[00:06.30]时间不匹配"
)), [
    { time: 1, text: "original one", translation: "译文一" },
    { time: 2, text: "original two", translation: "" },
    { time: 3, text: "", translation: "" },
    { time: 4, text: "same", translation: "" },
    { time: 5, text: "original five", translation: "" },
    { time: 6, text: "original six", translation: "" },
]);
assert.deepEqual(plain(api.withTranslations("[00:01]first\n[00:01.10]second", "[00:01.10]第二句")), [
    { time: 1, text: "first", translation: "" },
    { time: 1.1, text: "second", translation: "第二句" },
]);
assert.deepEqual(plain(api.withTranslations("[00:01]first\n[00:01]second", "[00:01]唯一译文")), [
    { time: 1, text: "first", translation: "" },
    { time: 1, text: "second", translation: "唯一译文" },
]);
const duplicateLines = api.withTranslations("[00:01]original\n[00:01]original", "[00:01]译文");
assert.equal(duplicateLines.length, 1);
assert.equal(api.preferredText(duplicateLines[duplicateLines.length - 1]), "译文");
assert.equal(api.withTranslations("[00:10]original", "[00:10.2]译文")[0].translation, "译文");
assert.equal(api.withTranslations("[00:01]original", "unsynced translation")[0].translation, "");
assert.equal(api.preferredText({ text: "original", translation: "译文" }), "译文");
assert.equal(api.preferredText({ text: "original", translation: "" }), "original");
assert.equal(api.preferredText({ text: "original", translation: "译文" }, false), "original");
assert.equal(api.preferredText({ text: "original", translation: "译文" }, true), "译文");
assert.equal(api.preferredText({ text: "", translation: "stray" }), "");
assert.equal(api.preferredText(null), "");

{
    const { api, requests } = fixture();
    const results = [];
    api.fetchLyrics("netease", "title & more", "artist", "album", 180, result => results.push(plain(result)));
    assert.equal(requests[0].url.hostname, "music.163.com");
    assert.equal(requests[0].url.searchParams.get("s"), "title & more artist");
    requests[0].reply({ result: { songs: [{ id: 123 }] } });
    assert.equal(requests[1].url.searchParams.get("tv"), "-1");
    requests[1].reply({
        lrc: { lyric: "[00:01]original\n[00:02]second" },
        tlyric: { lyric: "[00:01]译文" },
    });
    assert.deepEqual(results, [[
        { time: 1, text: "original", translation: "译文" },
        { time: 2, text: "second", translation: "" },
    ]]);
    api.fetchLyrics("netease", "title & more", "artist", "album", 180, result => results.push(plain(result)));
    assert.equal(requests.length, 2);
    assert.deepEqual(results[0], results[1]);
    api.fetchLyrics("netease", "title & more", "artist", "live album", 180, () => {});
    assert.equal(requests.length, 3);
    api.fetchLyrics("netease", "title & more", "artist", "live album", 200, () => {});
    assert.equal(requests.length, 4);
}

{
    const { api, requests } = fixture();
    let result;
    api.fetchLyrics("netease", "title", "artist", "", 0, value => { result = plain(value); });
    requests[0].reply({ result: { songs: [{ id: 123 }] } });
    requests[1].reply({ lrc: { lyric: "[00:01]original" } });
    assert.deepEqual(result, [{ time: 1, text: "original", translation: "" }]);
    assert.equal(requests.length, 2);
}

{
    const { api, requests } = fixture();
    let result;
    api.fetchLyrics("netease", "title", "artist", "album", 180, value => { result = plain(value); });
    requests[0].reply({ result: { songs: [{ id: 123 }] } });
    requests[1].reply({ lrc: { lyric: "[00:01]" } });
    assert.equal(requests[2].url.hostname, "lrclib.net");
    assert.equal(requests[2].url.searchParams.get("album_name"), "album");
    assert.equal(requests[2].url.searchParams.get("duration"), "180");
    requests[2].reply({ syncedLyrics: "[00:01]fallback" });
    assert.deepEqual(result, [{ time: 1, text: "fallback", translation: "" }]);
}

{
    const { api, requests } = fixture();
    const results = [];
    api.fetchLyrics("netease", "title", "artist", "", 0, value => results.push(plain(value)));
    requests[0].reply("bad json");
    requests[0].onerror();
    assert.equal(requests.length, 2);
    requests[1].reply({}, 503);
    requests[1].onerror();
    assert.deepEqual(results, [[]]);
    api.fetchLyrics("netease", "title", "artist", "", 0, value => results.push(plain(value)));
    assert.equal(requests.length, 2);
    assert.deepEqual(results, [[], []]);
}

for (const provider of ["netease_only", "lrclib_only"]) {
    const { api, requests } = fixture();
    let calls = 0;
    api.fetchLyrics(provider, "title", "artist", "", 0, value => {
        assert.deepEqual(plain(value), []);
        calls++;
    });
    requests[0].reply({}, 404);
    assert.equal(requests.length, 1);
    assert.equal(calls, 1);
}

{
    const { api, requests } = fixture();
    api.fetchLyrics("lrclib", "title", "artist", "", 0, () => {});
    assert.equal(requests[0].url.hostname, "lrclib.net");
    requests[0].reply({}, 404);
    assert.equal(requests[1].url.hostname, "music.163.com");
}

{
    const { api, requests } = fixture();
    let oldCalls = 0;
    let currentCalls = 0;
    api.fetchLyrics("lrclib_only", "cached", "artist", "", 0, () => {});
    requests[0].reply({ syncedLyrics: "[00:01]cached" });
    api.fetchLyrics("lrclib_only", "old", "artist", "", 0, () => { oldCalls++; });
    api.fetchLyrics("lrclib_only", "cached", "artist", "", 0, () => { currentCalls++; });
    requests[1].reply({ syncedLyrics: "[00:01]stale" });
    assert.equal(oldCalls, 0);
    assert.equal(currentCalls, 1);
    api.fetchLyrics("lrclib_only", "old", "artist", "", 0, () => { oldCalls++; });
    assert.equal(requests.length, 3);
    api.clearCache();
    requests[2].reply({ syncedLyrics: "[00:01]stale again" });
    assert.equal(oldCalls, 0);
    api.fetchLyrics("lrclib_only", "cached", "artist", "", 0, () => {});
    assert.equal(requests.length, 4);
}

{
    const { api, requests } = fixture();
    let oldCalls = 0;
    api.fetchLyrics("netease", "old", "artist", "", 0, () => { oldCalls++; });
    api.fetchLyrics("netease", "current", "artist", "", 0, () => {});
    requests[0].reply({}, 503);
    assert.equal(requests.length, 2);
    assert.equal(oldCalls, 0);
    api.fetchLyrics("netease", "missing artist", "", "", 0, value => assert.deepEqual(plain(value), []));
    assert.equal(requests.length, 2);
}

{
    const { api, requests } = fixture();
    let calls = 0;
    api.fetchLyrics("netease", "title", "artist", "", 0, () => { calls++; });
    api.cancelPending();
    assert.equal(requests[0].aborted, true);
    requests[0].reply({ result: { songs: [{ id: 123 }] } });
    assert.equal(requests.length, 1, "cancelled search must not start a lyric request");
    assert.equal(calls, 0);

    api.fetchLyrics("netease", "title", "artist", "", 0, () => { calls++; });
    requests[1].reply({ result: { songs: [{ id: 123 }] } });
    assert.equal(requests.length, 3);
    api.cancelPending();
    assert.equal(requests[2].aborted, true);
    requests[2].reply({}, 503);
    assert.equal(requests.length, 3, "cancelled lyric request must not start provider fallback");
    assert.equal(calls, 0);
    assert.equal(api._pendingRequests.length, 0);
}

console.log("DMS bilingual lyrics offline checks passed");
