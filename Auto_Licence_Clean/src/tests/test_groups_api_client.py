from unittest.mock import MagicMock, patch
import pytest
import sys
import os

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))


@patch("groups_api_client.requests.post")
def test_get_access_token_success(mock_post):
    """Should return the access token from the OAuth2 response."""
    mock_post.return_value.json.return_value = {"access_token": "my-token"}
    mock_post.return_value.raise_for_status = MagicMock()

    import groups_api_client
    token = groups_api_client.get_access_token()

    assert token == "my-token"


@patch("groups_api_client.requests.post")
def test_get_access_token_missing_token_raises(mock_post):
    """Should raise ValueError if the response contains no access_token."""
    mock_post.return_value.json.return_value = {}
    mock_post.return_value.raise_for_status = MagicMock()

    import groups_api_client
    with pytest.raises(ValueError, match="No access_token"):
        groups_api_client.get_access_token()


@patch("groups_api_client.requests.post")
@patch("groups_api_client.requests.delete")
def test_revoke_licences_single_batch(mock_delete, mock_post):
    """Should call the API once for a list smaller than BATCH_SIZE."""
    mock_post.return_value.json.return_value = {"access_token": "my-token"}
    mock_post.return_value.raise_for_status = MagicMock()

    mock_delete.return_value.json.return_value = {"status": "OK"}
    mock_delete.return_value.status_code = 200
    mock_delete.return_value.raise_for_status = MagicMock()

    import groups_api_client
    emails = ["user1@loreal.com", "user2@loreal.com"]
    summary = groups_api_client.revoke_licences(emails)

    assert summary["total"] == 2
    assert summary["revoked"] == 2
    assert summary["failed"] == 0
    assert mock_delete.call_count == 1


@patch("groups_api_client.requests.post")
@patch("groups_api_client.requests.delete")
def test_revoke_licences_multiple_batches(mock_delete, mock_post):
    """Should split into multiple API calls when list exceeds BATCH_SIZE."""
    mock_post.return_value.json.return_value = {"access_token": "my-token"}
    mock_post.return_value.raise_for_status = MagicMock()

    mock_delete.return_value.json.return_value = {"status": "OK"}
    mock_delete.return_value.status_code = 200
    mock_delete.return_value.raise_for_status = MagicMock()

    import config
    import groups_api_client

    emails = [f"user{i}@loreal.com" for i in range(25)]  # 25 users > BATCH_SIZE (20)
    summary = groups_api_client.revoke_licences(emails)

    expected_batches = -(-25 // config.BATCH_SIZE)  # ceiling division
    assert mock_delete.call_count == expected_batches
    assert summary["revoked"] == 25
    assert summary["failed"] == 0


@patch("groups_api_client.requests.post")
@patch("groups_api_client.requests.delete")
def test_revoke_licences_partial_failure(mock_delete, mock_post):
    """Should continue processing remaining batches when one batch fails."""
    mock_post.return_value.json.return_value = {"access_token": "my-token"}
    mock_post.return_value.raise_for_status = MagicMock()

    http_error = MagicMock()
    http_error.response.status_code = 400
    http_error.response.text = "Bad Request"

    import requests as req
    mock_delete.side_effect = [
        req.HTTPError(response=http_error),  # first batch fails
        MagicMock(json=lambda: {"status": "OK"}, status_code=200,
                  raise_for_status=MagicMock()),  # second batch succeeds
    ]

    import config
    import groups_api_client

    emails = [f"user{i}@loreal.com" for i in range(config.BATCH_SIZE + 1)]
    summary = groups_api_client.revoke_licences(emails)

    assert summary["failed"] == config.BATCH_SIZE
    assert summary["revoked"] == 1
    assert len(summary["errors"]) == 1


def test_revoke_licences_empty_list():
    """Should return zero counts immediately if there are no users."""
    import groups_api_client
    summary = groups_api_client.revoke_licences([])

    assert summary["total"] == 0
    assert summary["revoked"] == 0
    assert summary["failed"] == 0
