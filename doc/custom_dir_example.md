# Example of custom directory

<pre>
<b>custom</b>/
├── <b>agate</b>
│   ├── applications
│   │   ├── my_app.json
│   │   └── another_app.json
│   ├── groups
│   │   └── my_group.json
│   └── webapp
│       ├── dist
│       │   └── index.html
│       └── WEB-INF
│           └── classes
│               └── i18n
│                   └── en.json
├── <b>apache</b>
│   ├── certs
│   │   ├── fullchain.pem
│   │   └── privkey.pem
│   ├── conf
│   │   └── custom.conf
│   └── html
│       ├── favicon.ico
│       ├── index.html
│       └── logo.png
├── <b>drupal</b>
│   ├── customize.sql
│   ├── Makefile
│   ├── modules
│   │   └── my_module
│   │       ├── my_module.info
│   │       ├── my_module.module
│   │       └── my_module.tpl.php
│   └── sites
│       └── all
│           ├── libraries
│           │   └── angular-app
│           │       ├── ng-obiba
│           │       │   └── dist
│           │       │       └── css
│           │       │           └── ng-obiba.css
│           │       └── ng-obiba-mica
│           │           └── dist
│           │               └── ng-obiba-mica.js
│           ├── modules
│           │   └── obiba_mica
│           │       ├── includes
│           │       │   └── Obiba
│           │       │       └── ObibaMicaClient
│           │       │           └── Datasets
│           │       │               └── VariableStatistics.php
│           │       ├── obiba_mica_dataset
│           │       │   ├── obiba_mica_variable-page-detail.inc
│           │       │   └── templates
│           │       │       ├── obiba_mica_dataset-detail.tpl.php
│           │       │       └── obiba_mica_variable-detail.tpl.php
│           │       └── obiba_mica_study
│           │           ├── js
│           │           │   └── obiba-mica-study-dce-detail-modal.js
│           │           ├── obiba_mica_study_dce-detail-modal.inc
│           │           └── templates
│           │               ├── obiba_mica_study_dce-detail-modal.tpl.php
│           │               └── study-detail
│           │                   └── obiba_mica_study-detail.tpl.php
│           └── themes
│               └── obiba_bootstrap
│                   ├── bg.jpg
│                   ├── css
│                   │   └── style.css
│                   └── logo.png
├── <b>mica</b>
│   ├── ehcache.xml
│   ├── forms
│   │   ├── individual-studies
│   │   │   ├── data-collection-event.json
│   │   │   ├── individual-study.json
│   │   │   └── population.json
│   │   └── search-criteria
│   │       └── mica_search_criteria.json
│   ├── mica-taxonomy.yml
│   ├── opal_creds
│   │   └── my_account.json
│   └── webapp
│       ├── dist
│       │   └── index.html
│       └── WEB-INF
│           └── classes
│               └── i18n
│                   └── en.json
└── <b>opal</b>
    ├── taxonomies
    │   ├── maelstrom
    │   │   ├── additionalInformation.json
    │   │   ├── cognition.json
    │   │   ├── generalHealth.json
    │   │   ├── habits.json
    │   │   ├── harmonization.json
    │   │   └── social.json
    │   └── my_taxonomies
    │       ├── my_tax_1.json
    │       ├── my_tax_2.json
    │       └── my_tax_n.json
    └── webapp
        └── ui
            └── image
                └── opal.ico
</pre>