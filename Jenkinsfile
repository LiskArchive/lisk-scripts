pipeline {
  agent { node { label 'shellcheck' } }
  stages {
    stage ('shellcheck') {
      steps {
        sh '''#!/bin/bash -xe
        cd packaged
        shellcheck *.sh
        cd ../downloaded
        '''
      }
    }
  }
}
