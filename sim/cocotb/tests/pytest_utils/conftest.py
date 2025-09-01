import  pytest

# fixture for the test module
@pytest.fixture
def test(request):
    return request.config.getoption("--test") or 'test_basic'

# fixture for waves (0/1)
@pytest.fixture
def waves(request):
    return request.config.getoption("--waves") or 0

# register argument
def pytest_addoption(parser):
    parser.addoption(
        "--test",
        action="store",
        default='cocotb_basic_test',
        help="Which test case to run"
    )
    parser.addoption(
        "--waves",
        action="store",
        default=0,
        type=int,
        help="Enable waveform dumping"
    )
