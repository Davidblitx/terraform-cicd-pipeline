import pytest
import json
from app import app


@pytest.fixture
def client():
    """
    This creates a test client — a fake browser that can
    make requests to your app without actually running a server.
    Every test function receives this client as an argument.
    """
    app.config['TESTING'] = True
    with app.test_client() as client:
        yield client


class TestHomeRoute:
    def test_home_returns_200(self, client):
        """Home route must return HTTP 200"""
        response = client.get('/')
        assert response.status_code == 200

    def test_home_returns_json(self, client):
        """Home route must return JSON content type"""
        response = client.get('/')
        assert response.content_type == 'application/json'

    def test_home_has_status_field(self, client):
        """Response must contain a status field"""
        response = client.get('/')
        data = json.loads(response.data)
        assert 'status' in data

    def test_home_status_is_running(self, client):
        """Status field must say 'running'"""
        response = client.get('/')
        data = json.loads(response.data)
        assert data['status'] == 'running'

    def test_home_has_message(self, client):
        """Response must contain a message field"""
        response = client.get('/')
        data = json.loads(response.data)
        assert 'message' in data


class TestHealthRoute:
    def test_health_returns_200(self, client):
        """Health route must return HTTP 200"""
        response = client.get('/health')
        assert response.status_code == 200

    def test_health_returns_json(self, client):
        """Health check must return JSON"""
        response = client.get('/health')
        assert response.content_type == 'application/json'

    def test_health_status_is_healthy(self, client):
        """Health status must say 'healthy'"""
        response = client.get('/health')
        data = json.loads(response.data)
        assert data['status'] == 'healthy'


class TestInfoRoute:
    def test_info_returns_200(self, client):
        """Info route must return HTTP 200"""
        response = client.get('/info')
        assert response.status_code == 200

    def test_info_has_platform(self, client):
        """Info must contain platform field"""
        response = client.get('/info')
        data = json.loads(response.data)
        assert 'platform' in data


class TestNonExistentRoute:
    def test_unknown_route_returns_404(self, client):
        """Unknown routes must return 404"""
        response = client.get('/this-does-not-exist')
        assert response.status_code == 404
