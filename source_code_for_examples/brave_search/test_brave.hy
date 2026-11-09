;; Tests for brave.hy  --  run with:  uv run pytest
;;
;; requests.get is replaced with a fake, so no API key or network is needed.

(import pytest)
(import brave)


(defclass FakeResponse []
  (defn __init__ [self payload] (setv self.payload payload))
  (defn json [self] self.payload))

(setv sample-payload
  {"web" {"results" [{"title" "Sedona" "url" "https://example.com/sedona"
                      "description" "A city in Arizona" "extra" "ignored"}
                     {"title" "Red Rocks" "url" "https://example.com/rocks"
                      "description" "Scenic area"}]}})


(defn test-brave-search-parses-results [monkeypatch]
  (monkeypatch.setenv "BRAVE_SEARCH_API_KEY" "secret-key")
  (setv captured {})
  (defn fake-get [url #** kwargs]
    (.update captured kwargs)
    (setv (get captured "url") url)
    (FakeResponse sample-payload))
  (monkeypatch.setattr brave.requests "get" fake-get)

  (assert (= (brave.brave_search "Sedona Arizona")
             [["Sedona" "https://example.com/sedona" "A city in Arizona"]
              ["Red Rocks" "https://example.com/rocks" "Scenic area"]]))
  (assert (= (get captured "url") "https://api.search.brave.com/res/v1/web/search"))
  (assert (= (get captured "params") {"q" "Sedona Arizona"}))
  (assert (= (get captured "headers") {"X-Subscription-Token" "secret-key"})))

(defn test-brave-search-no-results [monkeypatch]
  (monkeypatch.setenv "BRAVE_SEARCH_API_KEY" "k")
  (monkeypatch.setattr brave.requests "get"
    (fn [url #** kwargs] (FakeResponse {"web" {"results" []}})))
  (assert (= (brave.brave_search "nothing") [])))

(defn test-brave-search-requires-api-key [monkeypatch]
  (monkeypatch.delenv "BRAVE_SEARCH_API_KEY" :raising False)
  (with [(pytest.raises KeyError)]
    (brave.brave_search "anything")))
