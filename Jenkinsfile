pipeline {
  agent { node { label 'shellcheck' } }
  stages {
    stage ('shellcheck') {
      steps {
        dir('downloaded') {
	  sh 'shellcheck -x *.sh'
	}
      }
    }
  }
}
