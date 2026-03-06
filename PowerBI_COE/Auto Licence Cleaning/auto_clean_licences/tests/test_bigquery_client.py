from unittest.mock import MagicMock, patch
import pytest
import sys
import os

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))


@patch("bigquery_client.bigquery.Client")
def test_get_users_to_revoke_returns_emails(mock_bq_class):
    """Should return a list of email addresses from BigQuery results."""
    mock_row_1 = MagicMock()
    mock_row_1.user_email = "john.doe@loreal.com"
    mock_row_2 = MagicMock()
    mock_row_2.user_email = "jane.smith@loreal.com"

    mock_client = MagicMock()
    mock_client.query.return_value.result.return_value = [mock_row_1, mock_row_2]
    mock_bq_class.return_value = mock_client

    import bigquery_client
    emails = bigquery_client.get_users_to_revoke()

    assert emails == ["john.doe@loreal.com", "jane.smith@loreal.com"]


@patch("bigquery_client.bigquery.Client")
def test_get_users_to_revoke_empty_result(mock_bq_class):
    """Should return an empty list when no users match the criteria."""
    mock_client = MagicMock()
    mock_client.query.return_value.result.return_value = []
    mock_bq_class.return_value = mock_client

    import bigquery_client
    emails = bigquery_client.get_users_to_revoke()

    assert emails == []


@patch("bigquery_client.bigquery.Client")
def test_get_users_to_revoke_raises_on_bq_error(mock_bq_class):
    """Should propagate BigQuery exceptions."""
    mock_client = MagicMock()
    mock_client.query.side_effect = Exception("BigQuery connection error")
    mock_bq_class.return_value = mock_client

    import bigquery_client
    with pytest.raises(Exception, match="BigQuery connection error"):
        bigquery_client.get_users_to_revoke()
