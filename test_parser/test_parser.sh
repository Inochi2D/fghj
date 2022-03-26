dub build --compiler=ldc2
if [ -d JSONTestSuite ]; then
	echo "JSONTestSuite already exist"
else
	git clone https://github.com/nst/JSONTestSuite
fi
cp run_fghj_tests.py JSONTestSuite/run_fghj_tests.py
cd JSONTestSuite
python3 run_fghj_tests.py
