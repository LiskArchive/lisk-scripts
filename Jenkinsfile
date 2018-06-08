pipeline {
  agent { node { label 'shellcheck' } }
  stages {
    stage ('shellcheck') {
      steps {
	dir('packaged') {
	  sh 'shellcheck *.sh'
	}
	dir('downloaded') {
	  sh 'shellcheck *.sh'
	}
      }
    }
  }
}
