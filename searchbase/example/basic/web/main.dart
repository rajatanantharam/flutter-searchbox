import 'dart:html';
import 'package:searchbase/searchbase.dart';

class DefaultUriPolicy implements UriPolicy {
  DefaultUriPolicy();
  bool allowsUri(String uri) {
    return true;
  }
}

void main() {
  final index = 'gitxplore-app';
  final url = 'https://@arc-cluster-appbase-demo-6pjy6z.searchbase.io';
  final credentials = 'a03a1cb71321:75b6603d-9456-4a5a-af6b-a487b309eb61';
  final searchbase = new SearchBase(index, url, credentials,
      appbaseConfig: new AppbaseSettings(recordAnalytics: true));
  // Register search component => To render the suggestions
  final searchComponent = searchbase.register('search-component', {
    'enablePopularSuggestions': true,
    'dataField': [
      'name',
      'description',
      'name.raw',
      'fullname',
      'owner',
      'topics'
    ]
  });

// Register filter component with dependency on search component
  final filterComponent = searchbase.register('language-filter', {
    'type': QueryType.term,
    'dataField': 'language.keyword',
    'react': {'and': 'search-component'},
    'value': List<String>()
  });

// Register result component with react dependency on search and filter component => To render the results
  final resultComponent = searchbase.register('result-component', {
    'dataField': 'name',
    'react': {
      'and': ['search-component', 'language-filter']
    },
  });

  // Render results
  querySelector('#output').innerHtml = """
    <div id="root">
      <h2 class="text-center">Searchbase Demo with Facet</h2>
      <div id="autocomplete" class="autocomplete">
        <input class="autocomplete-input" id="input" />
        <ul class="autocomplete-result-list"></ul>
      </div>
      <div class="row">
        <div class="col">
          <div class="filter" id="language-filter"></div>
        </div>
        <div class="col">
          <div id="results">
            <div class="loading">Loading results... </div>
          </div>
        </div>
      </div>
    </div>
  """;
  final input = querySelector('#input');
  void handleInput(e) {
    // Set the value to fetch the suggestions
    searchComponent.setValue(e.target.value,
        options: Options(triggerDefaultQuery: true));
  }

  input.addEventListener('input', handleInput);

  void handleKeyPress(e) {
    // Fetch the results
    if (e.key == 'Enter') {
      e.preventDefault();
      searchComponent.triggerCustomQuery();
    }
  }

  input.addEventListener('keydown', handleKeyPress);

  final resultElement = querySelector('#results');
  // Fetch initial results
  resultComponent.triggerDefaultQuery();

  resultComponent.subscribeToStateChanges((change) {
    final results = change['results']['next'];
    final items = results.data?.map((i) {
      return """
    <div id=${i['_id']} class="result-set">
      <div class="image">
        <img src=${i['avatar']} alt=${i['name']} />
      </div>
      <div class="details">
        <h4>${i['name']}</h4>
        <p>${i['description']}</p>
      </div>
    </div>""";
    });
    final resultStats = """<p class="results-stats">
                          Showing ${results.numberOfResults} in ${results.time}ms
                        <p>""";

    resultElement.setInnerHtml("${resultStats}${items.join('')}",
        validator: new NodeValidatorBuilder.common()
          ..allowHtml5()
          ..allowElement('img',
              attributes: ['src'], uriPolicy: new DefaultUriPolicy()));
  }, ['results']);

  // Fetch initial filter options
  filterComponent.triggerDefaultQuery();

  filterComponent.subscribeToStateChanges((change) {
    final aggregations = change['aggregationData']['next'];
    final container = document.getElementById('language-filter');
    container.setInnerHtml('');
    aggregations.data.forEach((i) {
      if (i['_key'] != null) {
        final checkbox = document.createElement('input');
        checkbox.setAttribute('type', 'checkbox');
        checkbox.setAttribute('name', i['_key']);
        checkbox.setAttribute('value', i['_key']);
        checkbox.id = i['_key'];
        checkbox.addEventListener('click', (event) {
          final List<String> values =
              filterComponent.value != null ? filterComponent.value : [];
          if (values.contains(i['_key'])) {
            values.remove(i['_key']);
          } else {
            values.add(i['_key']);
          }
          // Set filter value and trigger custom query
          filterComponent.setValue(values,
              options: Options(stateChanges: true, triggerCustomQuery: true));
        });
        final label = document.createElement('label');
        label.setAttribute('htmlFor', 'i._key');
        label.setInnerHtml("${i['_key']}(${i['_doc_count']})");
        final div = document.createElement('div');
        div.append(checkbox);
        div.append(label);
        container.append(div);
      }
    });
  }, ['aggregationData']);

  searchComponent.subscribeToStateChanges((change) {
    print('Track State Updates');
    print("Search Suggestions");
    window.console.log(searchComponent.suggestions);
  }, ['results']);
}