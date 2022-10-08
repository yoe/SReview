pipeline {
        agent {
                kubernetes {
                        yaml '''
                        apiVersion: v1
                        kind: Pod
                        metadata:
                        spec:
                          containers:
                          - name: postgres
                            image: postgres:9.6
                            imagePullPolicy: Always
                            env:
                            - name: POSTGRES_DB
                              value: "sreview"
                            - name: POSTGRES_USER
                              value: "sreview"
                            - name: POSTGRES_PASSWORD
                              value: ""
                            - name: POSTGRES_HOST_AUTH_METHOD
                              value: "trust"
                          - name: minio
                            image: minio/minio:latest
                            command:
                            - server
                            - /data
                            tty: true
                          - name: perl
                            image: perl:latest
                            command:
                            - cat
                            tty: true
                            env:
                            - name: SREVIEWTEST_DB
                              value: "sreview;host=postgres;user=sreview"
                            - name: SREVIEWTEST_S3_CONFIG
                              value: '{"default":{"aws_access_key_id":"minioadmin","aws_secret_access_key":"minioadmin","secure":0,"host":minio:9000"}}'
                            - name: SREVIEWTES_BUCKET
                              value: 'test'
                            - name: SREVIEW_COMMAND_TUNE
                              value: '{"bs1770gain":"0.5","inkscape":"0.9"}'
                            - name: JUNIT_OUTPUT_FILE
                              value: "junit_output.xml"
                        '''
                }
        }
        stages {
                stage('Install deps') {
                        steps {
				container('perl') {
					sh "apt-get update; apt-get -y --no-install-recommends install inkscape ffmpeg bs1770gain"
					sh "cpanm --notest ExtUtils::Depends Devel::Cover TAP::Harness::JUnit"
					sh "cpanm --notest --installdeps ."
					sh "perl .ci/setup-minio.pl"
				}
                        }
                }
                stage('Build') {
                        steps {
				container('perl') {
					sh "perl Makefile.PL"
					sh "cover -delete"
					withEnv(["HARNESS_PERL_SWITCHES=-MDevel::Cover"]) {
						sh "prove -v -l --harness TAP::Harness::JUnit"
					}
					sh "cover"
				}
                        }
                }
        }
}
